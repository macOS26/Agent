import Foundation
import MessagesBridge

// ============================================================================
// SendMessage - Unified script for sending messages and images via Messages
//
// INPUT: ~/Documents/AgentScript/json/SendMessage_input.json
// OUTPUT: ~/Documents/AgentScript/json/SendMessage_output.json
//
// JSON fields:
//   - recipient (required): Contact name, phone number, or email
//   - message (optional): Text message to send
//   - imagePath (optional): Path to image file to send
//
// NOTE: Image paths should reference files from the Photos library:
//   ~/Pictures/Photos Library.photoslibrary/originals/{folder}/{filename}
//   These are the actual image files stored by the Photos app.
//
// You can send:
//   - Text only: {recipient, message}
//   - Image only: {recipient, imagePath}
//   - Both: {recipient, message, imagePath}
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // JSON file paths - read from input, write to output
    let inputPath = "\(NSHomeDirectory())/Documents/AgentScript/json/SendMessage_input.json"
    let outputPath = "\(NSHomeDirectory())/Documents/AgentScript/json/SendMessage_output.json"
    
    // Read input JSON
    guard let inputData = FileManager.default.contents(atPath: inputPath) else {
        print("Could not read input file: \(inputPath)")
        writeOutput(outputPath, success: false, error: "Input file not found: \(inputPath)")
        return 1
    }
    
    // Parse JSON
    guard let json = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
        print("Could not parse JSON from input file")
        writeOutput(outputPath, success: false, error: "Invalid JSON format")
        return 1
    }
    
    guard let recipientHandle = json["recipient"] as? String else {
        print("Missing required field: recipient")
        writeOutput(outputPath, success: false, error: "Missing required field: recipient")
        return 1
    }
    
    let message = json["message"] as? String
    let imagePath = json["imagePath"] as? String
    
    // Must have at least message or imagePath
    if message == nil && imagePath == nil {
        print("Must provide either message or imagePath (or both)")
        writeOutput(outputPath, success: false, error: "Must provide either message or imagePath")
        return 1
    }
    
    print("Recipient: \(recipientHandle)")
    if let msg = message { print("Message: \(msg)") }
    if let img = imagePath { print("Image: \(img)") }
    
    // Connect to Messages
    guard let messages: MessagesApplication = SBApplication(bundleIdentifier: "com.apple.MobileSMS") else {
        print("Could not connect to Messages app")
        writeOutput(outputPath, success: false, error: "Could not connect to Messages app")
        return 1
    }
    
    // Find participant by searching chats first, then top-level participants
    var targetParticipant: MessagesParticipant? = nil
    
    // Search chats
    if let chats = messages.chats?() {
        for i in 0..<chats.count {
            guard let chat = chats.object(at: i) as? MessagesChat,
                  let chatParticipants = chat.participants?() else { continue }
            for j in 0..<chatParticipants.count {
                guard let participant = chatParticipants.object(at: j) as? MessagesParticipant else { continue }
                let handle = participant.handle ?? ""
                let name = participant.name ?? ""
                let fullName = participant.fullName ?? ""
                
                if handle.lowercased().contains(recipientHandle.lowercased()) ||
                   name.lowercased().contains(recipientHandle.lowercased()) ||
                   fullName.lowercased().contains(recipientHandle.lowercased()) {
                    targetParticipant = participant
                    break
                }
            }
            if targetParticipant != nil { break }
        }
    }
    
    // Search top-level participants
    if targetParticipant == nil {
        if let participants = messages.participants?() {
            for i in 0..<participants.count {
                guard let participant = participants.object(at: i) as? MessagesParticipant else { continue }
                let handle = participant.handle ?? ""
                let name = participant.name ?? ""
                let fullName = participant.fullName ?? ""
                
                if handle.lowercased().contains(recipientHandle.lowercased()) ||
                   name.lowercased().contains(recipientHandle.lowercased()) ||
                   fullName.lowercased().contains(recipientHandle.lowercased()) {
                    targetParticipant = participant
                    break
                }
            }
        }
    }
    
    guard let participant = targetParticipant else {
        print("Could not find participant: \(recipientHandle)")
        writeOutput(outputPath, success: false, error: "Could not find participant: \(recipientHandle)")
        return 1
    }
    
    // Send text message first (if provided)
    if let msg = message, !msg.isEmpty {
        messages.send?(msg, to: participant)
        print("Sent message: \(msg)")
    }
    
    // Send image (if provided)
    if let imgPath = imagePath {
        guard FileManager.default.fileExists(atPath: imgPath) else {
            print("Image file not found: \(imgPath)")
            writeOutput(outputPath, success: false, error: "Image file not found: \(imgPath)")
            return 1
        }
        let fileURL = URL(fileURLWithPath: imgPath)
        messages.send?(fileURL, to: participant)
        print("Image sent to \(recipientHandle)")
    }
    
    writeOutput(outputPath, success: true, recipient: recipientHandle, message: message, imagePath: imagePath)
    return 0
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, recipient: String? = nil, message: String? = nil, imagePath: String? = nil) {
    var output: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        output["error"] = error
    }
    
    if success {
        if let recipient = recipient { output["recipient"] = recipient }
        if let message = message { output["message"] = message }
        if let imagePath = imagePath { output["imagePath"] = imagePath }
    }
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted) else { return }
    try? jsonData.write(to: URL(fileURLWithPath: path))
}