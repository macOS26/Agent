import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    return generateBridge()
}

// MARK: - Type Mapping

private let typeDict: [String: String] = [
    "BOOL": "Bool",
    "double": "Double",
    "float": "Float",
    "long": "Int",
    "long long": "Int64",
    "int": "Int",
    "unsigned int": "UInt32",
    "short": "Int16",
    "id": "Any",
    "SEL": "Selector",
    "NSArray": "[Any]",
    "NSData": "Data",
    "NSDate": "Date",
    "NSDictionary": "[AnyHashable : Any]",
    "NSInteger": "Int",
    "NSString": "String",
    "NSURL": "URL",
    "NSRect": "NSRect",
    "NSPoint": "NSPoint",
    "NSNumber": "NSNumber",
    "NSColor": "NSColor",
]

private let swiftKeywords: Set<String> = [
    "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
    "import", "init", "inout", "internal", "let", "open", "operator", "private",
    "protocol", "public", "static", "struct", "subscript", "typealias", "var",
    "break", "case", "continue", "default", "defer", "do", "else", "fallthrough",
    "for", "guard", "if", "in", "repeat", "return", "switch", "where", "while",
    "as", "Any", "catch", "false", "is", "nil", "rethrows", "super", "self",
    "Self", "throw", "throws", "true", "try", "_"
]

private func safeName(_ name: String) -> String {
    swiftKeywords.contains(name) ? "`\(name)`" : name
}

private func mapType(_ objcType: String) -> String {
    var t = objcType.trimmingCharacters(in: .whitespaces)
    t = t.replacingOccurrences(of: " *", with: "")
    t = t.replacingOccurrences(of: "*", with: "")
    t = t.trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("SBElementArray") { return "SBElementArray" }
    if t.hasPrefix("NSArray") { return "[Any]" }
    return typeDict[t] ?? t
}

nonisolated(unsafe) private var knownEnumNames: Set<String> = []

private let primitiveTypes: Set<String> = [
    "BOOL", "Bool", "SEL", "int", "long", "long long", "double", "float",
    "short", "unsigned int", "Int", "Int16", "Int64", "UInt32", "Double", "Float",
    "NSInteger", "NSUInteger", "CGFloat"
]

private func isObjectType(_ t: String) -> Bool {
    let stripped = t.replacingOccurrences(of: " *", with: "").replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
    if primitiveTypes.contains(stripped) { return false }
    if stripped == "id" || stripped == "SBObject" { return true }
    if stripped.hasPrefix("NS") || stripped.hasPrefix("SB") { return true }
    if knownEnumNames.contains(stripped) { return false }
    if stripped.first?.isUppercase == true { return true }
    return false
}

// MARK: - Enum Case Conversion

private func convertEnumCase(prefix: String, caseName: String) -> String {
    var name = caseName
    if name.hasPrefix(prefix) {
        name = String(name.dropFirst(prefix.count))
    }
    guard !name.isEmpty else { return caseName }

    var result = ""
    var i = name.startIndex
    while i < name.endIndex && name[i].isUppercase {
        let next = name.index(after: i)
        if next < name.endIndex && name[next].isLowercase && result.count > 0 {
            break
        }
        if let ch = name[i].lowercased().first {
            result.append(ch)
        }
        i = next
    }
    if i < name.endIndex {
        result += String(name[i...])
    }

    return swiftKeywords.contains(result) ? "`\(result)`" : result
}

// MARK: - Four-Char Code Conversion

private func fourCharCode(_ s: String) -> String {
    var chars = s.replacingOccurrences(of: "'", with: "")
    chars = chars.replacingOccurrences(of: "\\?", with: "?")
    chars = chars.replacingOccurrences(of: "\\\\", with: "\\")
    guard chars.count == 4 else { return s }
    var value: UInt32 = 0
    for c in chars.unicodeScalars {
        value = (value << 8) | UInt32(c.value)
    }
    return String(format: "0x%08x", value)
}

// MARK: - Header Parser

private struct ParsedEnum {
    let name: String
    var cases: [(caseName: String, rawValue: String, comment: String)]
}

private struct ParsedProperty {
    let name: String
    let type: String
    let isReadonly: Bool
    let comment: String
    let isObject: Bool
}

private struct ParsedMethod {
    let name: String
    let parameters: [(label: String, type: String)]
    let returnType: String?
    let comment: String
    let returnsElementArray: Bool
}

private struct ParsedProtocol {
    let name: String
    let superProtocol: String?
    let properties: [ParsedProperty]
    let methods: [ParsedMethod]
    let isInterface: Bool
    let superClass: String?
}

private let objcAttributes: Set<String> = [
    "NS_RETURNS_NOT_RETAINED", "NS_RETURNS_RETAINED",
    "__nullable", "__nonnull", "_Nullable", "_Nonnull",
    "nullable", "nonnull", "__kindof"
]

private func parseProperty(_ line: String) -> ParsedProperty? {
    guard line.hasPrefix("@property") else { return nil }
    var rest = line.replacingOccurrences(of: "@property ", with: "")

    var isReadonly = false
    if rest.hasPrefix("(") {
        if let closeP = rest.firstIndex(of: ")") {
            let attrs = String(rest[rest.index(after: rest.startIndex)...rest.index(before: closeP)])
            isReadonly = attrs.contains("readonly")
            rest = String(rest[rest.index(after: closeP)...]).trimmingCharacters(in: .whitespaces)
        }
    }

    for attr in objcAttributes {
        rest = rest.replacingOccurrences(of: attr, with: "")
    }

    var comment = ""
    if let slashSlash = rest.range(of: "//") {
        comment = String(rest[slashSlash.upperBound...]).trimmingCharacters(in: .whitespaces)
        rest = String(rest[..<slashSlash.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
    rest = rest.replacingOccurrences(of: ";", with: "").trimmingCharacters(in: .whitespaces)

    let tokens = rest.components(separatedBy: " ").filter { !$0.isEmpty }
    guard tokens.count >= 2 else { return nil }
    guard let lastName = tokens.last else { return nil }
    let name = lastName.replacingOccurrences(of: "*", with: "")
    let rawType = tokens.dropLast().joined(separator: " ")
    let objc = isObjectType(rawType)
    let swiftType = mapType(rawType)

    return ParsedProperty(name: name, type: swiftType, isReadonly: isReadonly, comment: comment, isObject: objc)
}

private func parseMethod(_ line: String) -> ParsedMethod? {
    guard line.hasPrefix("- (") || line.hasPrefix("-(") else { return nil }

    var rest = line
    var comment = ""
    if let slashSlash = rest.range(of: "//") {
        comment = String(rest[slashSlash.upperBound...]).trimmingCharacters(in: .whitespaces)
        rest = String(rest[..<slashSlash.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
    rest = rest.replacingOccurrences(of: ";", with: "").trimmingCharacters(in: .whitespaces)

    for attr in objcAttributes {
        rest = rest.replacingOccurrences(of: attr, with: "")
    }
    while rest.contains("  ") {
        rest = rest.replacingOccurrences(of: "  ", with: " ")
    }

    guard let openP = rest.firstIndex(of: "("),
          let closeP = rest.firstIndex(of: ")") else { return nil }
    let returnTypeRaw = String(rest[rest.index(after: openP)..<closeP]).trimmingCharacters(in: .whitespaces)
    let isVoid = returnTypeRaw == "void"
    let returnsElementArray = returnTypeRaw.contains("SBElementArray")
    let returnType = isVoid ? nil : mapType(returnTypeRaw)

    rest = String(rest[rest.index(after: closeP)...]).trimmingCharacters(in: .whitespaces)

    var parameters: [(String, String)] = []
    var methodName = ""

    if !rest.contains(":") {
        methodName = rest.trimmingCharacters(in: .whitespaces)
    } else {
        let parts = rest.components(separatedBy: ":")
        methodName = parts[0].trimmingCharacters(in: .whitespaces)

        for pi in 1..<parts.count {
            var part = parts[pi].trimmingCharacters(in: .whitespaces)
            guard !part.isEmpty else { continue }

            guard let pOpen = part.firstIndex(of: "("),
                  let pClose = part.firstIndex(of: ")") else { continue }
            let paramType = String(part[part.index(after: pOpen)..<pClose])
            part = String(part[part.index(after: pClose)...]).trimmingCharacters(in: .whitespaces)

            let tokens = part.components(separatedBy: " ").filter { !$0.isEmpty }
            let paramName = tokens.first?.replacingOccurrences(of: "*", with: "") ?? "_"

            let swiftType = mapType(paramType)
            let argType = isObjectType(paramType) ? "\(swiftType)!" : swiftType

            if pi == 1 {
                parameters.append(("_ \(safeName(paramName.replacingOccurrences(of: "_", with: "")))", argType))
            } else {
                let label = parts[pi - 1].components(separatedBy: " ").last?.trimmingCharacters(in: .whitespaces) ?? "_"
                let cleanLabel = label.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: ")", with: "")
                if cleanLabel.hasSuffix("_") {
                    let stripped = String(cleanLabel.dropLast())
                    parameters.append(("\(safeName(stripped)) \(cleanLabel)", argType))
                } else {
                    parameters.append((safeName(cleanLabel), argType))
                }
            }
        }
    }

    return ParsedMethod(name: methodName, parameters: parameters, returnType: returnType, comment: comment, returnsElementArray: returnsElementArray)
}

private func parseHeader(_ content: String, appName: String) -> (enums: [ParsedEnum], protocols: [ParsedProtocol]) {
    let lines = content.components(separatedBy: "\n")
    var enums: [ParsedEnum] = []
    var protocols: [ParsedProtocol] = []
    var i = 0

    var categoryProps: [String: [ParsedProperty]] = [:]
    var categoryMethods: [String: [ParsedMethod]] = [:]

    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)

        if line.hasPrefix("enum ") && line.hasSuffix("{") {
            let enumName = line.replacingOccurrences(of: "enum ", with: "")
                .replacingOccurrences(of: " {", with: "")
                .trimmingCharacters(in: .whitespaces)
            var cases: [(String, String, String)] = []
            i += 1
            while i < lines.count {
                let eLine = lines[i].trimmingCharacters(in: .whitespaces)
                if eLine.hasPrefix("}") { break }
                if eLine.hasPrefix("typedef") { i += 1; continue }
                if let eqRange = eLine.range(of: " = ") {
                    let caseName = String(eLine[eLine.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let rest = String(eLine[eqRange.upperBound...])
                    var rawValue = ""
                    if let q1 = rest.firstIndex(of: "'") {
                        let afterQ1 = rest.index(after: q1)
                        if let q2 = rest[afterQ1...].firstIndex(of: "'") {
                            let code = String(rest[q1...q2])
                            rawValue = fourCharCode(code)
                        }
                    }
                    var comment = ""
                    if let slashStar = rest.range(of: "/* "), let starSlash = rest.range(of: " */") {
                        comment = String(rest[slashStar.upperBound..<starSlash.lowerBound])
                    }
                    if !rawValue.isEmpty {
                        let isDuplicate = cases.contains { $0.1 == rawValue }
                        if !isDuplicate {
                            cases.append((caseName, rawValue, comment))
                        }
                    }
                }
                i += 1
            }
            if !cases.isEmpty {
                enums.append(ParsedEnum(name: enumName, cases: cases))
                knownEnumNames.insert(enumName)
            }
        }

        if line.hasPrefix("@protocol ") && !line.contains("<") && !line.contains(";") {
            let protoName = line.replacingOccurrences(of: "@protocol ", with: "").trimmingCharacters(in: .whitespaces)
            var props: [ParsedProperty] = []
            var methods: [ParsedMethod] = []
            i += 1
            while i < lines.count {
                let pLine = lines[i].trimmingCharacters(in: .whitespaces)
                if pLine == "@end" { break }
                if let prop = parseProperty(pLine) { props.append(prop) }
                if let method = parseMethod(pLine) { methods.append(method) }
                i += 1
            }
            protocols.append(ParsedProtocol(name: protoName, superProtocol: nil, properties: props, methods: methods, isInterface: false, superClass: nil))
        }

        if line.hasPrefix("@interface ") {
            if line.contains("(") && line.contains(")") {
                let baseName = line.replacingOccurrences(of: "@interface ", with: "")
                    .components(separatedBy: " ").first ?? ""
                var props: [ParsedProperty] = []
                var methods: [ParsedMethod] = []
                i += 1
                while i < lines.count {
                    let cLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if cLine == "@end" { break }
                    if let prop = parseProperty(cLine) { props.append(prop) }
                    if let method = parseMethod(cLine) { methods.append(method) }
                    i += 1
                }
                categoryProps[baseName, default: []].append(contentsOf: props)
                categoryMethods[baseName, default: []].append(contentsOf: methods)
            } else {
                let decl = line.replacingOccurrences(of: "@interface ", with: "")
                let parts = decl.components(separatedBy: " : ")
                let className = parts[0].trimmingCharacters(in: .whitespaces)
                var superClass: String? = nil
                var adoptedProtocols: [String] = []
                if parts.count > 1 {
                    var rest = parts[1]
                    if let angleBracket = rest.range(of: "<") {
                        let protoStr = String(rest[angleBracket.upperBound...])
                            .replacingOccurrences(of: ">", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        adoptedProtocols = protoStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        rest = String(rest[..<angleBracket.lowerBound]).trimmingCharacters(in: .whitespaces)
                    }
                    superClass = rest.trimmingCharacters(in: .whitespaces)
                }

                var props: [ParsedProperty] = []
                var methods: [ParsedMethod] = []
                i += 1
                while i < lines.count {
                    let iLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if iLine == "@end" { break }
                    if let prop = parseProperty(iLine) { props.append(prop) }
                    if let method = parseMethod(iLine) { methods.append(method) }
                    i += 1
                }

                var superProto: String
                if let sc = superClass, sc.hasPrefix("SB") {
                    superProto = "\(sc)Protocol"
                } else if let sc = superClass {
                    superProto = sc
                } else {
                    superProto = "SBObjectProtocol"
                }
                let allProtocols = ([superProto] + adoptedProtocols).joined(separator: ", ")

                protocols.append(ParsedProtocol(name: className, superProtocol: allProtocols, properties: props, methods: methods, isInterface: true, superClass: superClass))
            }
        }

        i += 1
    }

    for j in 0..<protocols.count {
        let name = protocols[j].name
        if let extraProps = categoryProps[name] {
            protocols[j] = ParsedProtocol(
                name: protocols[j].name,
                superProtocol: protocols[j].superProtocol,
                properties: protocols[j].properties + extraProps,
                methods: protocols[j].methods + (categoryMethods[name] ?? []),
                isInterface: protocols[j].isInterface,
                superClass: protocols[j].superClass
            )
        }
    }

    return (enums, protocols)
}

// MARK: - Swift Emitter

private func emitSwift(appName: String, enums: [ParsedEnum], protocols: [ParsedProtocol]) -> String {
    var out = ""

    func emit(_ s: String = "") { out += s + "\n" }

    for e in enums {
        emit("// MARK: \(e.name)")
        emit("@objc public enum \(e.name) : AEKeyword {")
        for c in e.cases {
            let caseName = convertEnumCase(prefix: e.name, caseName: c.caseName)
            let commentStr = c.comment.isEmpty ? "" : " /* \(c.comment) */"
            emit("    case \(caseName) = \(c.rawValue)\(commentStr)")
        }
        emit("}\n")
    }

    for p in protocols {
        emit("// MARK: \(p.name)")
        let extends = p.superProtocol.map { ": \($0)" } ?? ""
        emit("@objc public protocol \(p.name)\(extends) {")

        var emittedProps: Set<String> = []
        for prop in p.properties where !emittedProps.contains(prop.name) {
            emittedProps.insert(prop.name)
            let commentStr = prop.comment.isEmpty ? "" : " // \(prop.comment)"
            emit("    @objc optional var \(safeName(prop.name)): \(prop.type) { get }\(commentStr)")
        }

        var emittedMethods: Set<String> = []
        for method in p.methods where !emittedMethods.contains(method.name) {
            emittedMethods.insert(method.name)
            let commentStr = method.comment.isEmpty ? "" : " // \(method.comment)"
            let params = method.parameters.map { "\($0.0): \($0.1)" }.joined(separator: ", ")
            let returnStr = method.returnType.map { " -> \($0)" } ?? ""
            emit("    @objc optional func \(safeName(method.name))(\(params))\(returnStr)\(commentStr)")
        }

        emit("}")

        if p.isInterface {
            let extensionClass: String
            if let sc = p.superClass, sc.hasPrefix("SB") {
                extensionClass = sc
            } else {
                extensionClass = "SBObject"
            }
            emit("extension \(extensionClass): \(p.name) {}\n")
        } else {
            emit()
        }
    }

    return out
}

// MARK: - Pipeline

private func runCmd(_ cmd: String) -> (output: String, status: Int32) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", cmd]
    process.standardOutput = pipe
    process.standardError = pipe
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
}

// MARK: - Entry Point

func generateBridge() -> Int32 {
    // When loaded as dylib, read arguments from AGENT_SCRIPT_ARGS environment variable
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let args = argsString.components(separatedBy: " ").filter { !$0.isEmpty }
    guard !args.isEmpty else {
        print("Usage: GenerateBridge /Applications/AppName.app [output_dir]")
        print("       GenerateBridge AppName.h [output_dir]")
        print("")
        print("Generates a Swift ScriptingBridge protocol file from a macOS app.")
        print("If given an .app path, runs sdef + sdp automatically.")
        print("If given a .h file, converts it directly.")
        return 1
    }

    let input = args[0]
    let outputDir = args.count > 1 ? args[1] : FileManager.default.currentDirectoryPath

    var headerPath: String
    var appName: String

    if input.hasSuffix(".app") || input.hasSuffix(".app/") {
        let appPath = input
        appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: " ", with: "")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("generate_bridge_\(ProcessInfo.processInfo.processIdentifier)").path
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        print("Launching \(appName)...")
        _ = runCmd("open -a '\(appPath)' && sleep 2")

        print("Extracting scripting definition from \(appName)...")
        let sdefResult = runCmd("sdef '\(appPath)' 2>/dev/null")
        guard sdefResult.status == 0, !sdefResult.output.isEmpty else {
            print("Error: \(appName) does not have a scripting definition (sdef)")
            return 1
        }

        let sdefPath = "\(tempDir)/\(appName).sdef"
        do {
            try sdefResult.output.write(toFile: sdefPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing sdef: \(error.localizedDescription)")
            return 1
        }

        print("Generating Objective-C header...")
        let sdpResult = runCmd("cd '\(tempDir)' && sdp -fh --basename '\(appName)' '\(sdefPath)' 2>&1")
        headerPath = "\(tempDir)/\(appName).h"
        guard FileManager.default.fileExists(atPath: headerPath) else {
            print("Error: sdp failed to generate header")
            print(sdpResult.output)
            return 1
        }
    } else if input.hasSuffix(".h") {
        headerPath = input
        appName = URL(fileURLWithPath: input).deletingPathExtension().lastPathComponent
    } else {
        print("Error: Input must be an .app bundle or a .h header file")
        return 1
    }

    // Reset global state for repeated calls
    knownEnumNames = []

    print("Parsing \(appName).h...")
    guard let headerContent = try? String(contentsOfFile: headerPath, encoding: .utf8) else {
        print("Error: Could not read header file: \(headerPath)")
        return 1
    }
    let (enums, protocols) = parseHeader(headerContent, appName: appName)

    print("Generating Swift protocols...")
    let swift = emitSwift(appName: appName, enums: enums, protocols: protocols)

    let safeFileName = appName.replacingOccurrences(of: " ", with: "")
    let outputPath = "\(outputDir)/\(safeFileName).swift"
    do {
        try swift.write(toFile: outputPath, atomically: true, encoding: .utf8)
    } catch {
        print("Error writing output: \(error.localizedDescription)")
        return 1
    }

    print("Generated \(outputPath)")
    print("  \(enums.count) enums, \(protocols.count) protocols")
    return 0
}
