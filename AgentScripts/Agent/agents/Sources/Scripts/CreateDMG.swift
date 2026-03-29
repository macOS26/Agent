import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let fileManager = FileManager.default
    
    // Get arguments from AGENT_SCRIPT_ARGS env var or command line
    let envArgs = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var args: [String]
    if envArgs.isEmpty {
        args = ProcessInfo.processInfo.arguments
    } else {
        // Parse the env var string into individual arguments (handle quoted strings)
        args = ["CreateDmg"] // Add script name as first arg
        var currentArg = ""
        var inQuotes = false
        for char in envArgs {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == " " && !inQuotes {
                if !currentArg.isEmpty {
                    args.append(currentArg)
                    currentArg = ""
                }
            } else {
                currentArg.append(char)
            }
        }
        if !currentArg.isEmpty {
            args.append(currentArg)
        }
    }
    
    // Parse arguments: --app <path> --output <path> [--name <volume-name>] [--size <mb>] [--compress]
    var appPath: String?
    var outputPath: String?
    var volumeName = "DiskImage"
    var sizeMB = 200
    var compress = false
    
    var i = 1
    while i < args.count {
        switch args[i] {
        case "--app":
            appPath = i + 1 < args.count ? args[i + 1] : nil
            i += 2
        case "--output":
            outputPath = i + 1 < args.count ? args[i + 1] : nil
            i += 2
        case "--name":
            volumeName = i + 1 < args.count ? args[i + 1] : "DiskImage"
            i += 2
        case "--size":
            if let sizeStr = i + 1 < args.count ? args[i + 1] : nil {
                sizeMB = Int(sizeStr) ?? 200
            }
            i += 2
        case "--compress":
            compress = true
            i += 1
        default:
            i += 1
        }
    }
    
    guard let appPath = appPath else {
        print("Usage: CreateDmg --app <path-to-app> --output <dmg-path> [--name <volume-name>] [--size <mb>] [--compress]")
        print("Options:")
        print("  --app      Path to the .app bundle (required)")
        print("  --output   Output DMG path (optional, defaults to app path with .dmg extension)")
        print("  --name     Volume name shown when mounted (default: DiskImage)")
        print("  --size     Size in MB (default: 200)")
        print("  --compress Convert to compressed read-only UDZO format")
        print("\nExample: CreateDmg --app /path/to/MyApp.app --output /path/to/MyApp.dmg --name \"MyApp\" --compress")
        return 1
    }
    
    // Resolve paths
    let resolvedAppPath = (appPath as NSString).expandingTildeInPath
    let resolvedOutputPath = outputPath ?? resolvedAppPath.replacingOccurrences(of: ".app$", with: ".dmg", options: .regularExpression)
    
    // Check if app exists
    guard fileManager.fileExists(atPath: resolvedAppPath) else {
        print("Error: App not found at \(resolvedAppPath)")
        return 1
    }
    
    // Remove existing DMG if present
    if fileManager.fileExists(atPath: resolvedOutputPath) {
        do {
            try fileManager.removeItem(atPath: resolvedOutputPath)
            print("Removed existing DMG: \(resolvedOutputPath)")
        } catch {
            print("Error removing existing DMG: \(error)")
            return 1
        }
    }
    
    // Create temporary directory
    let tempDir = fileManager.temporaryDirectory.appendingPathComponent("dmg_build_\(UUID().uuidString)").path
    
    do {
        try fileManager.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    } catch {
        print("Error creating temp directory: \(error)")
        return 1
    }
    
    defer {
        try? fileManager.removeItem(atPath: tempDir)
    }
    
    // Copy app to temp directory
    let appName = (resolvedAppPath as NSString).lastPathComponent
    let tempAppPath = (tempDir as NSString).appendingPathComponent(appName)
    
    do {
        try fileManager.copyItem(atPath: resolvedAppPath, toPath: tempAppPath)
        print("Copied \(appName) to temp directory")
    } catch {
        print("Error copying app: \(error)")
        return 1
    }
    
    // Create DMG
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
    task.arguments = [
        "create",
        "-volname", volumeName,
        "-srcfolder", tempDir,
        "-ov",
        "-format", "UDRW",
        "-size", "\(sizeMB)m",
        resolvedOutputPath
    ]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    do {
        print("Creating DMG: \((resolvedOutputPath as NSString).lastPathComponent)...")
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if !output.isEmpty {
            print(output)
        }
        
        if task.terminationStatus == 0 {
            print("\n✓ Successfully created: \(resolvedOutputPath)")
            print("  Volume name: \(volumeName)")
            print("  Format: Read/Write (UDRW)")
            print("  Size: \(sizeMB) MB")
            
            if compress {
                // Convert to compressed UDZO format
                let compressedPath = resolvedOutputPath
                let tempRwPath = (resolvedOutputPath as NSString).deletingPathExtension + "_temp.dmg"
                
                // Rename the RW DMG temporarily
                do {
                    try fileManager.moveItem(atPath: resolvedOutputPath, toPath: tempRwPath)
                } catch {
                    print("Error preparing for compression: \(error)")
                    return 1
                }
                
                let convertTask = Process()
                convertTask.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                convertTask.arguments = [
                    "convert",
                    tempRwPath,
                    "-format", "UDZO",
                    "-o", compressedPath,
                    "-imagekey", "zlib-level=9"
                ]
                
                let convertPipe = Pipe()
                convertTask.standardOutput = convertPipe
                convertTask.standardError = convertPipe
                
                do {
                    print("\nConverting to compressed format...")
                    try convertTask.run()
                    convertTask.waitUntilExit()
                    
                    let convertData = convertPipe.fileHandleForReading.readDataToEndOfFile()
                    let convertOutput = String(data: convertData, encoding: .utf8) ?? ""
                    if !convertOutput.isEmpty {
                        print(convertOutput)
                    }
                    
                    // Remove temp RW DMG
                    try? fileManager.removeItem(atPath: tempRwPath)
                    
                    if convertTask.terminationStatus == 0 {
                        print("\n✓ Compressed DMG created: \(compressedPath)")
                        
                        // Show size savings
                        if let compressedAttrs = try? fileManager.attributesOfItem(atPath: compressedPath),
                           let compressedSize = compressedAttrs[.size] as? UInt64 {
                            let compressedMB = Double(compressedSize) / 1024 / 1024
                            print("  Final size: \(String(format: "%.2f", compressedMB)) MB")
                        }
                    } else {
                        print("Error compressing DMG, exit code: \(convertTask.terminationStatus)")
                        return 1
                    }
                } catch {
                    print("Error during compression: \(error)")
                    return 1
                }
            } else {
                print("\nTo customize:")
                print("  1. Open the DMG")
                print("  2. In Finder, use View > Show View Options")
                print("  3. Set background color/image")
                print("  4. Convert to compressed: hdiutil convert \"\(resolvedOutputPath)\" -format UDZO -o final.dmg")
            }
        } else {
            print("Error creating DMG, exit code: \(task.terminationStatus)")
        }
        
        return task.terminationStatus
    } catch {
        print("Error: \(error)")
        return 1
    }
}