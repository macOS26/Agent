import Foundation
import AVFoundation

// ============================================================================
// CapturePhoto - Capture photo from any available camera
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "param1=value1,param2=value2"
//     Parameters:
//       - camera=front|back|external (default: front, falls back to any available)
//       - output=/path/to/file.jpg (default: ~/Documents/AgentScript/photos/)
//       - json=true (output JSON to file)
//     Example: "camera=back,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/CapturePhoto_input.json
//     {
//       "camera": "front",
//       "output": "~/Documents/AgentScript/photos/myphoto.jpg",
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/CapturePhoto_output.json
//   {
//     "success": true,
//     "outputPath": "/Users/.../photo.jpg",
//     "timestamp": "2026-03-16T..."
//   }
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    capturePhoto()
    return 0
}

func capturePhoto() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/CapturePhoto_input.json"
    let jsonOutputPath = "\(home)/Documents/AgentScript/json/CapturePhoto_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var camera: String = "front"
    var outputPath: String? = nil
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "camera":
                    camera = value.lowercased()
                case "output", "path", "file":
                    outputPath = (value as NSString).expandingTildeInPath
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
        if let c = json["camera"] as? String { camera = c.lowercased() }
        if let o = json["output"] as? String { outputPath = (o as NSString).expandingTildeInPath }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    // Set default output path if not specified
    let photoDir = "\(home)/Documents/AgentScript/photos"
    let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let finalPath = outputPath ?? "\(photoDir)/photo_\(timestamp).jpg"
    
    // Ensure output directory exists
    let dir = (finalPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    
    print("📷 Capture Photo")
    print("═════════════════════════════════════")
    print("Camera: \(camera)")
    print("Output: \(finalPath)")
    
    // Check camera authorization
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        break
    case .notDetermined:
        print("\n⏳ Requesting camera access...")
        var granted = false
        let semaphore = DispatchSemaphore(value: 0)
        AVCaptureDevice.requestAccess(for: .video) { success in
            granted = success
            semaphore.signal()
        }
        semaphore.wait()
        if !granted {
            print("❌ Camera access denied")
            writeOutput(jsonOutputPath, success: false, error: "Camera access denied", outputJSON: outputJSON)
            return
        }
    default:
        print("❌ Camera access denied - check System Settings > Privacy & Security > Camera")
        writeOutput(jsonOutputPath, success: false, error: "Camera access denied", outputJSON: outputJSON)
        return
    }
    
    // Discover ALL video devices (built-in + external)
    let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external],
        mediaType: .video,
        position: .unspecified
    )
    
    let allDevices = discoverySession.devices
    
    print("\n📹 Available cameras:")
    if allDevices.isEmpty {
        print("  (none found)")
    } else {
        for (index, dev) in allDevices.enumerated() {
            let posStr: String
            switch dev.position {
            case .front: posStr = "front"
            case .back: posStr = "back"
            case .unspecified: posStr = "external"
            @unknown default: posStr = "unknown"
            }
            print("  [\(index)] \(dev.localizedName) (\(posStr))")
        }
    }
    
    // Find the requested camera
    var selectedDevice: AVCaptureDevice? = nil
    
    // First try exact position match
    let position: AVCaptureDevice.Position
    switch camera {
    case "back": position = .back
    case "front": position = .front
    default: position = .unspecified
    }
    
    // Try to find device at requested position
    if position != .unspecified {
        selectedDevice = allDevices.first { $0.position == position }
    }
    
    // Fall back to any available camera
    if selectedDevice == nil {
        // Prefer front, then back, then external
        selectedDevice = allDevices.first { $0.position == .front }
            ?? allDevices.first { $0.position == .back }
            ?? allDevices.first { $0.position == .unspecified }
            ?? allDevices.first
    }
    
    guard let device = selectedDevice else {
        print("\n❌ No camera available")
        writeOutput(jsonOutputPath, success: false, error: "No camera available", outputJSON: outputJSON)
        return
    }
    
    print("\n✅ Using: \(device.localizedName)")
    
    // Setup capture session
    let session = AVCaptureSession()
    session.beginConfiguration()
    
    // Use medium quality for faster capture
    if session.canSetSessionPreset(.medium) {
        session.sessionPreset = .medium
    }
    
    guard let input = try? AVCaptureDeviceInput(device: device) else {
        print("❌ Cannot create camera input")
        writeOutput(jsonOutputPath, success: false, error: "Cannot create camera input", outputJSON: outputJSON)
        return
    }
    
    if session.canAddInput(input) {
        session.addInput(input)
    } else {
        print("❌ Cannot add input to session")
        writeOutput(jsonOutputPath, success: false, error: "Cannot add input to session", outputJSON: outputJSON)
        return
    }
    
    let output = AVCapturePhotoOutput()
    if session.canAddOutput(output) {
        session.addOutput(output)
    } else {
        print("❌ Cannot add output to session")
        writeOutput(jsonOutputPath, success: false, error: "Cannot add output to session", outputJSON: outputJSON)
        return
    }
    
    session.commitConfiguration()

    let captureSemaphore = DispatchSemaphore(value: 0)
    let photoCaptureDelegate = PhotoCaptureDelegate()
    let fileURL = URL(fileURLWithPath: finalPath)
    photoCaptureDelegate.outputURL = fileURL
    photoCaptureDelegate.completionSemaphore = captureSemaphore

    // Start session and trigger capture on background thread.
    // Do NOT block inside this async block — doing so would cause a priority
    // inversion: a userInitiated thread waiting on an AVFoundation callback
    // delivered at base priority (the Xcode hang risk warning).
    DispatchQueue.global(qos: .utility).async {
        session.startRunning()
        Thread.sleep(forTimeInterval: 0.5)
        let settings = AVCapturePhotoSettings()
        if output.availablePhotoCodecTypes.contains(.jpeg) {
            settings.photoQualityPrioritization = .balanced
        }
        output.capturePhoto(with: settings, delegate: photoCaptureDelegate)
    }

    // Block only here (calling thread) — no userInitiated thread is waiting
    _ = captureSemaphore.wait(timeout: .now() + 6)
    session.stopRunning()
    
    if photoCaptureDelegate.success {
        print("✅ Photo captured successfully")
        print("📁 \(finalPath)")
        writeOutput(jsonOutputPath, success: true, outputPath: finalPath, outputJSON: outputJSON)
    } else {
        print("❌ Failed to capture photo")
        if let err = photoCaptureDelegate.error {
            print("   Error: \(err)")
        }
        writeOutput(jsonOutputPath, success: false, error: photoCaptureDelegate.error ?? "Failed to capture photo", outputJSON: outputJSON)
    }
}

func writeOutput(_ path: String, success: Bool, outputPath: String? = nil, error: String? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let outputPath = outputPath {
        result["outputPath"] = outputPath
    }
    
    if let error = error {
        result["error"] = error
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    var outputURL: URL?
    var success = false
    var error: String?
    var completionSemaphore: DispatchSemaphore?
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            completionSemaphore?.signal()
        }
        
        if let err = error {
            self.error = err.localizedDescription
            return
        }
        guard let data = photo.fileDataRepresentation(), let url = outputURL else { 
            self.error = "No photo data"
            return 
        }
        do {
            try data.write(to: url)
            success = true
        } catch {
            self.error = error.localizedDescription
            print("Error saving photo: \(error)")
        }
    }
}