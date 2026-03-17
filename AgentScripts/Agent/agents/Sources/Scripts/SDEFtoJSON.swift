import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    return convertSDEFs()
}

// MARK: - JSON Models

struct SDEFDocument: Codable {
    var suites: [Suite]
}

struct Suite: Codable {
    var name: String
    var commands: [Command]?
    var classes: [SDEFClass]?
    var enumerations: [Enumeration]?
}

struct Command: Codable {
    var name: String
    var description: String?
    var directParameter: DirectParameter?
    var parameters: [Parameter]?
    var result: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case directParameter = "direct_parameter"
        case parameters, result
    }
}

struct DirectParameter: Codable {
    var type: String?
    var description: String?
}

struct Parameter: Codable {
    var name: String
    var type: String?
    var description: String?
    var optional: Bool?
}

struct SDEFClass: Codable {
    var name: String
    var inherits: String?
    var description: String?
    var properties: [Property]?
    var elements: [String]?
    var respondsTo: [String]?

    enum CodingKeys: String, CodingKey {
        case name, inherits, description, properties, elements
        case respondsTo = "responds_to"
    }
}

struct Property: Codable {
    var name: String
    var type: String?
    var readonly: Bool?
    var description: String?
}

struct Enumeration: Codable {
    var name: String
    var values: [EnumValue]
}

struct EnumValue: Codable {
    var name: String
    var description: String?
}

// MARK: - XML Parser

class SDEFParser: NSObject, XMLParserDelegate {
    var document = SDEFDocument(suites: [])

    private var currentSuite: Suite?
    private var currentCommand: Command?
    private var currentClass: SDEFClass?
    private var currentEnum: Enumeration?
    private var skipHidden = false

    func parse(data: Data) -> SDEFDocument {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return document
    }

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attrs: [String: String]) {

        switch element {
        case "suite":
            if attrs["hidden"] == "yes" {
                skipHidden = true
                return
            }
            currentSuite = Suite(name: attrs["name"] ?? "")

        case "command":
            guard !skipHidden else { return }
            var cmd = Command(name: attrs["name"] ?? "")
            let desc = attrs["description"]
            if let d = desc, !d.isEmpty { cmd.description = d }
            currentCommand = cmd

        case "direct-parameter":
            guard !skipHidden, currentCommand != nil else { return }
            var dp = DirectParameter()
            if let t = attrs["type"], !t.isEmpty { dp.type = t }
            if let d = attrs["description"], !d.isEmpty { dp.description = d }
            currentCommand?.directParameter = dp

        case "parameter":
            guard !skipHidden, currentCommand != nil else { return }
            var p = Parameter(name: attrs["name"] ?? "")
            if let t = attrs["type"], !t.isEmpty { p.type = t }
            if let d = attrs["description"], !d.isEmpty { p.description = d }
            if attrs["optional"] == "yes" { p.optional = true }
            if currentCommand?.parameters == nil { currentCommand?.parameters = [] }
            currentCommand?.parameters?.append(p)

        case "result":
            guard !skipHidden, currentCommand != nil else { return }
            currentCommand?.result = attrs["type"]

        case "class", "class-extension":
            guard !skipHidden else { return }
            var cls = SDEFClass(name: attrs["name"] ?? attrs["extends"] ?? "")
            if let inh = attrs["inherits"], !inh.isEmpty { cls.inherits = inh }
            if let d = attrs["description"], !d.isEmpty { cls.description = d }
            currentClass = cls

        case "property":
            guard !skipHidden, currentClass != nil else { return }
            var prop = Property(name: attrs["name"] ?? "", type: attrs["type"])
            if attrs["access"] == "r" { prop.readonly = true }
            if let d = attrs["description"], !d.isEmpty { prop.description = d }
            if currentClass?.properties == nil { currentClass?.properties = [] }
            currentClass?.properties?.append(prop)

        case "element":
            guard !skipHidden, currentClass != nil else { return }
            if let t = attrs["type"] {
                if currentClass?.elements == nil { currentClass?.elements = [] }
                currentClass?.elements?.append(t)
            }

        case "responds-to":
            guard !skipHidden, currentClass != nil else { return }
            if let cmd = attrs["command"] {
                if currentClass?.respondsTo == nil { currentClass?.respondsTo = [] }
                currentClass?.respondsTo?.append(cmd)
            }

        case "enumeration":
            guard !skipHidden else { return }
            currentEnum = Enumeration(name: attrs["name"] ?? "", values: [])

        case "enumerator":
            guard !skipHidden, currentEnum != nil else { return }
            var v = EnumValue(name: attrs["name"] ?? "")
            if let d = attrs["description"], !d.isEmpty { v.description = d }
            currentEnum?.values.append(v)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI: String?, qualifiedName: String?) {

        switch element {
        case "suite":
            if skipHidden { skipHidden = false; return }
            if var s = currentSuite {
                // Only add suites with content
                let hasContent = (s.commands?.isEmpty == false) ||
                                 (s.classes?.isEmpty == false) ||
                                 (s.enumerations?.isEmpty == false)
                if hasContent {
                    // Strip empty arrays
                    if s.commands?.isEmpty == true { s.commands = nil }
                    if s.classes?.isEmpty == true { s.classes = nil }
                    if s.enumerations?.isEmpty == true { s.enumerations = nil }
                    document.suites.append(s)
                }
            }
            currentSuite = nil

        case "command":
            guard !skipHidden else { return }
            if let cmd = currentCommand {
                if currentSuite?.commands == nil { currentSuite?.commands = [] }
                currentSuite?.commands?.append(cmd)
            }
            currentCommand = nil

        case "class", "class-extension":
            guard !skipHidden else { return }
            if let cls = currentClass {
                if currentSuite?.classes == nil { currentSuite?.classes = [] }
                currentSuite?.classes?.append(cls)
            }
            currentClass = nil

        case "enumeration":
            guard !skipHidden else { return }
            if let e = currentEnum {
                if currentSuite?.enumerations == nil { currentSuite?.enumerations = [] }
                currentSuite?.enumerations?.append(e)
            }
            currentEnum = nil

        default:
            break
        }
    }
}

// MARK: - Entry Point

func convertSDEFs() -> Int32 {
    let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"]?
        .components(separatedBy: " ").filter { !$0.isEmpty } ?? []

    guard args.count >= 2 else {
        print("Usage: SDEFtoJSON <input_dir> <output_dir>")
        print("       SDEFtoJSON <input.sdef> <output.json>")
        print("")
        print("Converts SDEF XML files to compact JSON.")
        print("If given directories, converts all .sdef files.")
        return 1
    }

    let input = args[0]
    let output = args[1]
    let fm = FileManager.default

    var isDir: ObjCBool = false
    fm.fileExists(atPath: input, isDirectory: &isDir)

    if isDir.boolValue {
        // Batch convert directory
        try? fm.createDirectory(atPath: output, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(atPath: input) else {
            print("Error: Cannot read directory \(input)")
            return 1
        }
        let sdefs = files.filter { $0.hasSuffix(".sdef") }.sorted()
        var count = 0
        for file in sdefs {
            let name = (file as NSString).deletingPathExtension
            let inPath = "\(input)/\(file)"
            let outPath = "\(output)/\(name).json"
            if convertFile(inPath, to: outPath) {
                count += 1
            }
        }
        print("Converted \(count)/\(sdefs.count) SDEFs to JSON in \(output)")
    } else {
        // Single file
        if !convertFile(input, to: output) {
            return 1
        }
    }
    return 0
}

@discardableResult
func convertFile(_ inputPath: String, to outputPath: String) -> Bool {
    guard let data = FileManager.default.contents(atPath: inputPath) else {
        print("Error: Cannot read \(inputPath)")
        return false
    }

    let parser = SDEFParser()
    let doc = parser.parse(data: data)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let json = try? encoder.encode(doc) else {
        print("Error: Failed to encode \((inputPath as NSString).lastPathComponent)")
        return false
    }

    guard FileManager.default.createFile(atPath: outputPath, contents: json) else {
        print("Error: Cannot write \(outputPath)")
        return false
    }

    let name = (inputPath as NSString).lastPathComponent
    let inSize = data.count
    let outSize = json.count
    let pct = inSize > 0 ? Int(Double(outSize) / Double(inSize) * 100) : 0
    print("  \(name) → \(outSize / 1024)KB (\(pct)% of XML)")
    return true
}
