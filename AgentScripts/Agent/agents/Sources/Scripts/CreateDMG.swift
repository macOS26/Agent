import Foundation

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    createDMG()
    return 0
}

func createDMG() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/CreateDMG_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/CreateDMG_output.json"
    
    // Default values
    var appName = "Agent!"
    var sourcePath = "/Applications/Agent!.app"
    var destFolder = "\(home)/Documents/Releases/Agent"
    var dmgName = "Agent.dmg"
    var volumeName = "Agent"
    
    // Read input JSON if exists
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        appName = json["appName"] as? String ?? appName
        sourcePath = json["sourcePath"] as? String ?? sourcePath
        destFolder = json["destFolder"] as? String ?? destFolder
        dmgName = json["dmgName"] as? String ?? dmgName
        volumeName = json["volumeName"] as? String ?? volumeName
    }
    
    print("Creating DMG for \(appName)...")
    print("Source: \(sourcePath)")
    print("Destination: \(destFolder)/\(dmgName)")
    
    // Create destination folder if needed
    do {
        try FileManager.default.createDirectory(atPath: destFolder, withIntermediateDirectories: true)
    } catch {
        print("Error creating destination folder: \(error)")
        writeOutput(outputPath, success: false, error: "Failed to create destination folder")
        return
    }
    
    let tempDir = "\(destFolder)/dmg_temp_\(UUID().uuidString)"
    let dmgPath = "\(destFolder)/\(dmgName)"
    
    // Remove existing DMG if present
    try? FileManager.default.removeItem(atPath: dmgPath)
    
    // Create temp directory
    do {
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    } catch {
        print("Error creating temp directory: \(error)")
        writeOutput(outputPath, success: false, error: "Failed to create temp directory")
        return
    }
    
    // Copy app to temp
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", """
    cp -R '\(sourcePath)' '\(tempDir)/'
    ln -s /Applications '\(tempDir)/Applications'
    """]
    
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        print("Error copying app: \(error)")
        try? FileManager.default.removeItem(atPath: tempDir)
        writeOutput(outputPath, success: false, error: "Failed to copy app")
        return
    }
    
    // Create DMG
    let dmgTask = Process()
    dmgTask.launchPath = "/usr/bin/hdiutil"
    dmgTask.arguments = ["create", "-volname", volumeName, "-srcfolder", tempDir, "-ov", "-format", "UDZO", dmgPath]
    
    do {
        try dmgTask.run()
        dmgTask.waitUntilExit()
    } catch {
        print("Error creating DMG: \(error)")
        try? FileManager.default.removeItem(atPath: tempDir)
        writeOutput(outputPath, success: false, error: "Failed to create DMG")
        return
    }
    
    // Cleanup temp
    try? FileManager.default.removeItem(atPath: tempDir)
    
    // Get file size
    let attributes = try? FileManager.default.attributesOfItem(atPath: dmgPath)
    let fileSize = (attributes?[.size] as? Int64) ?? 0
    let sizeMB = Double(fileSize) / 1024.0 / 1024.0
    
    print("DMG created successfully: \(dmgPath)")
    print(String(format: "Size: %.1f MB", sizeMB))
    
    writeOutput(outputPath, success: true, dmgPath: dmgPath, sizeMB: sizeMB)
}

func writeOutput(_ path: String, success: Bool, dmgPath: String? = nil, sizeMB: Double? = nil, error: String? = nil) {
    var result: [String: Any] = ["success": success]
    if let dmgPath = dmgPath { result["dmgPath"] = dmgPath }
    if let sizeMB = sizeMB { result["sizeMB"] = sizeMB }
    if let error = error { result["error"] = error }
    
    if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}