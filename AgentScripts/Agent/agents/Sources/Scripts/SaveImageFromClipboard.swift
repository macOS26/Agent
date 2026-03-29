import Foundation
import AppKit

// ============================================================================
// SaveImageFromClipboard - Save clipboard image to file
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "outputPath=/path/to/image.png" or just the path directly
//     Example: "outputPath=~/Desktop/image.png"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/SaveImageFromClipboard_input.json
//     {
//       "outputPath": "~/Desktop/image.png",
//       "format": "png"
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/SaveImageFromClipboard_output.json
//   {
//     "success": true,
//     "outputPath": "/Users/.../image.png",
//     "size": { "width": 100, "height": 100 },
//     "fileSize": 12345
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    saveImageFromClipboard()
    return 0
}

func saveImageFromClipboard() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/SaveImageFromClipboard_input.json"
    let outputPathJSON = "\(home)/Documents/AgentScript/json/SaveImageFromClipboard_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var outputPath = "\(home)/Documents/AgentScript/images/clipboard_image.png"
    var format = "png"
    var outputJSON = false
    
    if !argsString.isEmpty {
        if argsString.contains("=") {
            let pairs = argsString.components(separatedBy: ",")
            for pair in pairs {
                let parts = pair.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    switch key {
                    case "outputPath", "path", "file":
                        outputPath = (value as NSString).expandingTildeInPath
                    case "format":
                        format = value.lowercased()
                    case "json":
                        outputJSON = value.lowercased() == "true"
                    default: break
                    }
                }
            }
        } else {
            // Treat entire string as output path
            outputPath = (argsString as NSString).expandingTildeInPath
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let path = json["outputPath"] as? String { outputPath = (path as NSString).expandingTildeInPath }
        if let f = json["format"] as? String { format = f.lowercased() }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    print("📋 Save Image from Clipboard")
    print("═════════════════════════════════════")
    print("Output: \(outputPath)")
    print("Format: \(format)")
    
    // Get image from clipboard
    guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
        print("❌ No image found in clipboard")
        writeOutput(outputPathJSON, success: false, error: "No image found in clipboard", outputJSON: outputJSON)
        return
    }
    
    // Ensure directory exists
    let dir = (outputPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    
    // Convert to appropriate format
    guard let tiffData = image.tiffRepresentation,
          let bitmapImage = NSBitmapImageRep(data: tiffData) else {
        print("❌ Failed to convert image")
        writeOutput(outputPathJSON, success: false, error: "Failed to convert image", outputJSON: outputJSON)
        return
    }
    
    let imageData: Data?
    let actualFormat: String
    
    switch format {
    case "jpg", "jpeg":
        imageData = bitmapImage.representation(using: .jpeg, properties: [:])
        actualFormat = "jpeg"
        if !outputPath.hasSuffix(".jpg") && !outputPath.hasSuffix(".jpeg") {
            outputPath = (outputPath as NSString).deletingPathExtension + ".jpg"
        }
    case "png":
        imageData = bitmapImage.representation(using: .png, properties: [:])
        actualFormat = "png"
        if !outputPath.hasSuffix(".png") {
            outputPath = (outputPath as NSString).deletingPathExtension + ".png"
        }
    case "tiff", "tif":
        imageData = bitmapImage.representation(using: .tiff, properties: [:])
        actualFormat = "tiff"
        if !outputPath.hasSuffix(".tiff") && !outputPath.hasSuffix(".tif") {
            outputPath = (outputPath as NSString).deletingPathExtension + ".tiff"
        }
    case "gif":
        imageData = bitmapImage.representation(using: .gif, properties: [:])
        actualFormat = "gif"
        if !outputPath.hasSuffix(".gif") {
            outputPath = (outputPath as NSString).deletingPathExtension + ".gif"
        }
    default:
        // Default to PNG
        imageData = bitmapImage.representation(using: .png, properties: [:])
        actualFormat = "png"
        if !outputPath.hasSuffix(".png") {
            outputPath = (outputPath as NSString).deletingPathExtension + ".png"
        }
    }
    
    guard let data = imageData else {
        print("❌ Failed to create \(format) data")
        writeOutput(outputPathJSON, success: false, error: "Failed to create \(format) data", outputJSON: outputJSON)
        return
    }
    
    do {
        try data.write(to: URL(fileURLWithPath: outputPath))
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        let fileSize = data.count
        
        print("✅ Image saved successfully")
        print("   Size: \(width) x \(height)")
        print("   Format: \(actualFormat)")
        print("   File size: \(fileSize) bytes")
        print("")
        print("📁 \(outputPath)")
        
        writeFullOutput(outputPathJSON, success: true, outputPath: outputPath, width: width, height: height, fileSize: fileSize, format: actualFormat, outputJSON: outputJSON)
    } catch {
        print("❌ Failed to save image: \(error)")
        writeOutput(outputPathJSON, success: false, error: "Failed to save image: \(error)", outputJSON: outputJSON)
    }
}

func writeOutput(_ path: String, success: Bool, error: String?, outputJSON: Bool) {
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

func writeFullOutput(_ path: String, success: Bool, outputPath: String, width: Int, height: Int, fileSize: Int, format: String, outputJSON: Bool) {
    guard outputJSON else { return }
    
    let result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "outputPath": outputPath,
        "size": ["width": width, "height": height],
        "fileSize": fileSize,
        "format": format
    ]
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}