import Foundation
import NotesBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listNotes()
    return 0
}

func listNotes() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/ListNotes_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/ListNotes_output.json"
    
    // Default options
    var limit = 10
    var showContent = false
    var showModified = true
    var outputJSON = false
    
    // Parse AGENT_SCRIPT_ARGS
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "limit": limit = Int(value) ?? 10
                case "content": showContent = value.lowercased() == "true"
                case "modified": showModified = value.lowercased() == "true"
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let l = json["limit"] as? Int { limit = l }
        if let c = json["content"] as? Bool { showContent = c }
        if let m = json["modified"] as? Bool { showModified = m }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    // Connect to Notes app
    guard let app: NotesApplication = SBApplication(bundleIdentifier: "com.apple.Notes") else {
        print("Could not connect to Notes.app")
        writeListNotesOutput(outputPath, success: false, error: "Could not connect to Notes.app", outputJSON: outputJSON)
        return
    }

    // Small delay to ensure app is responsive
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))

    print("Notes")
    print("=====")

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short

    var totalNotes = 0
    var folderCount = 0
    var allNotes: [[String: Any]] = []

    // Try to get notes from accounts first (more reliable)
    if let accounts = app.accounts?(), accounts.count > 0 {
        for i in 0..<accounts.count {
            guard let account = accounts.object(at: i) as? NotesAccount,
                  let accountName = account.name else { continue }

            if let folders = account.folders?(), folders.count > 0 {
                for j in 0..<folders.count {
                    guard let folder = folders.object(at: j) as? NotesFolder,
                          let folderName = folder.name,
                          let notes = folder.notes?() else { continue }

                    let count = notes.count
                    guard count > 0 else { continue }
                    totalNotes += count
                    folderCount += 1

                    print("\n[\(accountName)] \(folderName) (\(count) notes)")

                    let displayLimit = min(limit, count)
                    for k in 0..<displayLimit {
                        guard let note = notes.object(at: k) as? NotesNote,
                              let name = note.name else { continue }

                        let modified = showModified && note.modificationDate != nil 
                            ? dateFormatter.string(from: note.modificationDate!) 
                            : ""
                        
                        print("  - \(name)\(modified.isEmpty ? "" : "  [\(modified)]")")
                        
                        if showContent, let body = note.body {
                            let preview = body.count > 100 ? String(body.prefix(100)) + "..." : body
                            print("    \(preview.replacingOccurrences(of: "\n", with: " "))")
                        }
                        
                        allNotes.append([
                            "name": name,
                            "folder": folderName,
                            "account": accountName,
                            "modified": note.modificationDate ?? Date()
                        ] as [String : Any])
                    }
                    if count > limit {
                        print("  ... and \(count - limit) more")
                    }
                }
            }
        }
    }

    // Fallback: try app.folders() directly
    if totalNotes == 0, let folders = app.folders?(), folders.count > 0 {
        for i in 0..<folders.count {
            guard let folder = folders.object(at: i) as? NotesFolder,
                  let folderName = folder.name,
                  let notes = folder.notes?() else { continue }

            let count = notes.count
            guard count > 0 else { continue }
            totalNotes += count
            folderCount += 1

            print("\n\(folderName) (\(count) notes)")

            let displayLimit = min(limit, count)
            for j in 0..<displayLimit {
                guard let note = notes.object(at: j) as? NotesNote,
                      let name = note.name else { continue }

                let modified = showModified && note.modificationDate != nil 
                    ? dateFormatter.string(from: note.modificationDate!) 
                    : ""
                print("  - \(name)\(modified.isEmpty ? "" : "  [\(modified)]")")
                
                allNotes.append([
                    "name": name,
                    "folder": folderName,
                    "modified": note.modificationDate ?? Date()
                ] as [String : Any])
            }
            if count > limit {
                print("  ... and \(count - limit) more")
            }
        }
    }

    // Last resort: try app.notes() directly
    if totalNotes == 0, let notes = app.notes?(), notes.count > 0 {
        totalNotes = notes.count
        print("\nAll Notes (\(totalNotes) total)")

        let displayLimit = min(limit, totalNotes)
        for i in 0..<displayLimit {
            guard let note = notes.object(at: i) as? NotesNote,
                  let name = note.name else { continue }

            let modified = showModified && note.modificationDate != nil
                ? dateFormatter.string(from: note.modificationDate!)
                : ""
            print("  - \(name)\(modified.isEmpty ? "" : "  [\(modified)]")")
            
            allNotes.append([
                "name": name,
                "modified": note.modificationDate ?? Date()
            ] as [String : Any])
        }
        if totalNotes > limit {
            print("  ... and \(totalNotes - limit) more")
        }
    }

    if totalNotes == 0 {
        print("\nNo notes found. Make sure Notes.app is running and has notes.")
        print("Try: osascript -e 'tell application \"Notes\" to activate'")
    } else {
        print("\nTotal: \(totalNotes) notes in \(folderCount) folders")
    }
    
    // Write JSON output if requested
    if outputJSON {
        writeListNotesOutput(outputPath, success: true, notes: allNotes, total: totalNotes, outputJSON: true)
    }
}

func writeListNotesOutput(_ path: String, success: Bool, error: String? = nil, notes: [[String: Any]]? = nil, total: Int? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        result["error"] = error
    }
    
    if success {
        if let notes = notes { result["notes"] = notes }
        if let total = total { result["total"] = total }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}