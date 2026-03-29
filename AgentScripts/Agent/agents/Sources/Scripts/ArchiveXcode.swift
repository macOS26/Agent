import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // Configuration - can override via AGENT_SCRIPT_ARGS
    let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let parts = args.split(separator: " ").map(String.init)
    
    let projectPath = parts.count > 0 ? parts[0] : "/Users/toddbruss/Documents/GitHub/Agent/AgentXcode"
    let scheme = parts.count > 1 ? parts[1] : "Agent!"
    let projectFile = parts.count > 2 ? parts[2] : "\(projectPath)/Agent.xcodeproj"
    let archivePath = parts.count > 3 ? parts[3] : "\(projectPath)/build/Agent.xcarchive"
    let teamID = parts.count > 4 ? parts[4] : "469UCUB275"
    
    let exportPath = "\(projectPath)/build/export"
    let appName = scheme
    let credentialName = "App Store Connect Profile"
    
    print("=== Starting Archive and Notarization Process ===")
    print("Project: \(projectPath)")
    print("Scheme: \(scheme)")
    print("Project File: \(projectFile)")
    print("Archive Path: \(archivePath)")
    print("Team ID: \(teamID)")
    print("")
    fflush(stdout)
    
    // Create build directory if needed
    let buildDir = URL(fileURLWithPath: archivePath).deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
    
    // Helper function to run process with live output
    func runProcess(executable: String, arguments: [String], workingDir: String? = nil) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        if let dir = workingDir {
            task.currentDirectoryURL = URL(fileURLWithPath: dir)
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe
        
        // Stream stdout live
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print(output, terminator: "")
                fflush(stdout)
            }
        }
        
        // Stream stderr live
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                print(output, terminator: "")
                fflush(stdout)
            }
        }
        
        do {
            try task.run()
            task.waitUntilExit()
            
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            
            return task.terminationStatus
        } catch {
            print("Error running \(executable): \(error)")
            return 1
        }
    }
    
    // Step 1: Create Archive
    print("Step 1: Creating Archive...")
    let archiveResult = runProcess(
        executable: "/usr/bin/xcodebuild",
        arguments: [
            "-scheme", scheme,
            "-project", projectFile,
            "-configuration", "Release",
            "-archivePath", archivePath,
            "archive"
        ],
        workingDir: projectPath
    )
    
    if archiveResult != 0 {
        print("\n=== Archive Failed ===")
        print("Exit status: \(archiveResult)")
        return 1
    }
    print("\nArchive created successfully!\n")
    
    // Step 2: Export Archive
    print("Step 2: Exporting Archive...")
    
    // Create ExportOptions.plist
    let exportOptionsContent = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>method</key>
        <string>developer-id</string>
        <key>teamID</key>
        <string>\(teamID)</string>
        <key>signingStyle</key>
        <string>automatic</string>
    </dict>
    </plist>
    """
    
    let exportOptionsPath = "\(projectPath)/ExportOptions.plist"
    FileManager.default.createFile(atPath: exportOptionsPath, contents: exportOptionsContent.data(using: .utf8), attributes: nil)
    
    // Clean export directory
    try? FileManager.default.removeItem(atPath: exportPath)
    try? FileManager.default.createDirectory(atPath: exportPath, withIntermediateDirectories: true)
    
    let exportResult = runProcess(
        executable: "/usr/bin/xcodebuild",
        arguments: [
            "-exportArchive",
            "-archivePath", archivePath,
            "-exportOptionsPlist", exportOptionsPath,
            "-exportPath", exportPath
        ],
        workingDir: projectPath
    )
    
    if exportResult != 0 {
        print("\n=== Export Failed ===")
        print("Exit status: \(exportResult)")
        return 1
    }
    print("\nArchive exported successfully!\n")
    
    // Find the exported app
    let exportedAppPath = "\(exportPath)/\(appName).app"
    
    guard FileManager.default.fileExists(atPath: exportedAppPath) else {
        print("Error: Exported app not found at \(exportedAppPath)")
        return 1
    }
    
    print("Exported app: \(exportedAppPath)\n")
    
    // Step 3: Create ZIP for notarization
    print("Step 3: Creating ZIP for Notarization...")
    let zipPath = "\(exportPath)/\(appName)-notarize.zip"
    
    let zipResult = runProcess(
        executable: "/usr/bin/ditto",
        arguments: ["-c", "-k", "--keepParent", exportedAppPath, zipPath]
    )
    
    if zipResult != 0 {
        print("ZIP creation failed")
        return 1
    }
    print("ZIP created: \(zipPath)\n")
    
    // Step 4: Submit for notarization
    print("Step 4: Submitting for Notarization...")
    print("Note: This requires App Store Connect API key or app-specific password\n")
    
    // Check if credentials are stored
    let checkCredsResult = runProcess(
        executable: "/usr/bin/xcrun",
        arguments: ["notarytool", "history", "-p", credentialName]
    )
    
    if checkCredsResult != 0 {
        print("""
        ========================================
        NOTARIZATION CREDENTIALS NOT CONFIGURED
        ========================================
        
        To set up notarization, run:
        
        xcrun notarytool store-credentials "\(credentialName)" \\
            --apple-id YOUR_APPLE_ID \\
            --team-id \(teamID) \\
            --password YOUR_APP_SPECIFIC_PASSWORD
        
        Get app-specific password from:
        https://appleid.apple.com/account/manage
        
        Then run this script again.
        """)
        return 1
    }
    
    // Submit for notarization
    print("Submitting for notarization (this may take several minutes)...\n")
    let submitResult = runProcess(
        executable: "/usr/bin/xcrun",
        arguments: ["notarytool", "submit", "-p", credentialName, "--wait", "--timeout", "7200", zipPath]
    )
    
    if submitResult != 0 {
        print("\nNotarization submission failed")
        return 1
    }
    print("\nNotarization successful!\n")
    
    // Step 5: Staple ticket
    print("Step 5: Stapling Notarization Ticket...")
    
    let stapleResult = runProcess(
        executable: "/usr/bin/xcrun",
        arguments: ["stapler", "staple", exportedAppPath]
    )
    
    if stapleResult != 0 {
        print("Stapling failed")
        return 1
    }
    print("Ticket stapled successfully!\n")
    
    print("=== COMPLETE ===")
    print("Notarized app: \(exportedAppPath)")
    print("Open folder: \(exportPath)")
    
    // Open Finder to the export directory
    _ = runProcess(executable: "/usr/bin/open", arguments: [exportPath])
    
    return 0
}