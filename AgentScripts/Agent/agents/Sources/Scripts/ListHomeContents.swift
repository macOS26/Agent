import Foundation
import FinderBridge

// ============================================================================
// ListHomeContents - List contents of home directory via Finder
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - folder=Documents (subfolder to list, default: home root)
//       - depth=1 (how deep to recurse, default: 1)
//       - limit=10 (max items per folder, default: 20)
//       - json=true (output to JSON file)
//     Example: "folder=Documents,depth=2,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/ListHomeContents_input.json
//     {
//       "folder": "Documents",
//       "depth": 2,
//       "limit": 10,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/ListHomeContents_output.json
//   {
//     "success": true,
//     "folder": "Documents",
//     "folders": [...],
//     "files": [...],
//     "timestamp": "2026-03-16T..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listHomeContents()
    return 0
}

func listHomeContents() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/ListHomeContents_input.json"
    let jsonOutputPath = "\(home)/Documents/AgentScript/json/ListHomeContents_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var targetFolder = ""
    var depth = 1
    var limit = 20
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "folder":
                    targetFolder = value
                case "depth":
                    depth = Int(value) ?? 1
                case "limit":
                    limit = Int(value) ?? 20
                case "json":
                    outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let f = json["folder"] as? String { targetFolder = f }
        if let d = json["depth"] as? Int { depth = d }
        if let l = json["limit"] as? Int { limit = l }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let finder: FinderApplication = SBApplication(bundleIdentifier: "com.apple.finder") else {
        print("❌ Could not connect to Finder")
        writeOutput(jsonOutputPath, success: false, error: "Could not connect to Finder", outputJSON: outputJSON)
        return
    }
    
    print("📁 Home Directory Contents")
    print("═══════════════════════════════════════")
    
    // Get the target folder
    var targetContainer: FinderFolder? = nil
    var folderPath = ""
    
    if targetFolder.isEmpty {
        // Home root
        guard let homeFolder = finder.home else {
            print("❌ Could not get home folder")
            writeOutput(jsonOutputPath, success: false, error: "Could not get home folder", outputJSON: outputJSON)
            return
        }
        targetContainer = homeFolder
        folderPath = "~"
    } else {
        // Find subfolder
        guard let homeFolder = finder.home else {
            print("❌ Could not get home folder")
            writeOutput(jsonOutputPath, success: false, error: "Could not get home folder", outputJSON: outputJSON)
            return
        }
        
        if let folders = homeFolder.folders?() {
            for i in 0..<folders.count {
                if let folder = folders.object(at: i) as? FinderFolder,
                   let name = folder.name,
                   name.lowercased() == targetFolder.lowercased() {
                    targetContainer = folder
                    folderPath = "~/\(name)"
                    break
                }
            }
        }
        
        if targetContainer == nil {
            print("❌ Folder '\(targetFolder)' not found in home")
            writeOutput(jsonOutputPath, success: false, error: "Folder '\(targetFolder)' not found", outputJSON: outputJSON)
            return
        }
    }
    
    guard let container = targetContainer else {
        print("❌ Could not access folder")
        writeOutput(jsonOutputPath, success: false, error: "Could not access folder", outputJSON: outputJSON)
        return
    }
    
    print("Folder: \(folderPath)")
    print("Depth: \(depth)")
    print("Limit: \(limit) items per folder")
    print("")
    
    // Collect data
    var foldersResult: [[String: Any]] = []
    var filesResult: [[String: Any]] = []
    
    // Get folders
    print("--- FOLDERS ---")
    if let folders = container.folders?() {
        for i in 0..<min(limit, folders.count) {
            if let folder = folders.object(at: i) as? FinderFolder,
               let name = folder.name {
                print("  📁 \(name)")
                
                var folderInfo: [String: Any] = ["name": name]
                if let items = folder.items?(), items.count > 0 {
                    folderInfo["itemCount"] = items.count
                }
                foldersResult.append(folderInfo)
            }
        }
        if folders.count > limit {
            print("  ... and \(folders.count - limit) more folders")
        }
    }
    
    // Get files
    print("\n--- FILES ---")
    if let files = container.files?() {
        for i in 0..<min(limit, files.count) {
            if let file = files.object(at: i) as? FinderItem,
               let name = file.name {
                let size = file.size ?? 0
                let sizeStr = size > 1024 * 1024 ? "\(size / 1024 / 1024) MB" : 
                              size > 1024 ? "\(size / 1024) KB" : "\(size) bytes"
                print("  📄 \(name) (\(sizeStr))")
                
                var fileInfo: [String: Any] = ["name": name, "size": size]
                if let modified = file.modificationDate {
                    fileInfo["modified"] = ISO8601DateFormatter().string(from: modified as Date)
                }
                filesResult.append(fileInfo)
            }
        }
        if files.count > limit {
            print("  ... and \(files.count - limit) more files")
        }
    }
    
    // Recursive listing if depth > 1
    if depth > 1 {
        print("\n--- SUBFOLDERS ---")
        if let folders = container.folders?() {
            for i in 0..<min(limit, folders.count) {
                if let folder = folders.object(at: i) as? FinderFolder,
                   let name = folder.name {
                    print("\n\(name)/")
                    listFolderRecursive(folder, indent: "  ", currentDepth: 1, maxDepth: depth, limit: limit)
                }
            }
        }
    }
    
    print("\n═══════════════════════════════════════")
    print("Summary: \(foldersResult.count) folders, \(filesResult.count) files")
    
    // Write JSON output if requested
    if outputJSON {
        let result: [String: Any] = [
            "success": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "folder": folderPath,
            "folders": foldersResult,
            "files": filesResult
        ]
        
        try? FileManager.default.createDirectory(atPath: (jsonOutputPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: jsonOutputPath))
            print("\n📄 JSON saved to: \(jsonOutputPath)")
        }
    }
}

func listFolderRecursive(_ folder: FinderFolder, indent: String, currentDepth: Int, maxDepth: Int, limit: Int) {
    if currentDepth >= maxDepth { return }
    
    if let folders = folder.folders?() {
        for i in 0..<min(limit, folders.count) {
            if let subfolder = folders.object(at: i) as? FinderFolder,
               let name = subfolder.name {
                let items = subfolder.items?()
                let itemCount = items?.count ?? 0
                print("\(indent)📁 \(name)/ (\(itemCount) items)")
                listFolderRecursive(subfolder, indent: indent + "  ", currentDepth: currentDepth + 1, maxDepth: maxDepth, limit: limit)
            }
        }
    }
    
    if let files = folder.files?() {
        for i in 0..<min(limit, files.count) {
            if let file = files.object(at: i) as? FinderItem,
               let name = file.name {
                let size = file.size ?? 0
                print("\(indent)📄 \(name) (\(size) bytes)")
            }
        }
    }
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}