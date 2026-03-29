import Foundation
import MessagesBridge

// ============================================================================
// SendGroupMessage - Send message to a group chat via Messages app
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "chatId|message" (pipe-separated)
//     Example: "chat138755|Happy Birthday Max!"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/SendGroupMessage_input.json
//     {
//       "chatId": "chat138755",
//       "message": "Happy Birthday Max!"
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/SendGroupMessage_output.json
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    let result = sendGroupMessage()
    return result
}

func sendGroupMessage() -> Int32 {
    let home = NSHomeDirectory()
    let jsonDir = "\(home)/Documents/AgentScript/json"
    let inputPath = "\(jsonDir)/SendGroupMessage_input.json"
    let outputPath = "\(jsonDir)/SendGroupMessage_output.json"
    
    // Ensure json directory exists
    try? FileManager.default.createDirectory(atPath: jsonDir, withIntermediateDirectories: true)
    
    var chatId: String? = nil
    var message: String? = nil
    
    // Try AGENT_SCRIPT_ARGS first
    if let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"], !args.isEmpty {
        print("Reading from AGENT_SCRIPT_ARGS: \(args)")
        let parts = args.components(separatedBy: "|")
        if parts.count >= 2 {
            chatId = parts[0].trimmingCharacters(in: .whitespaces)
            message = parts[1...].joined(separator: "|").trimmingCharacters(in: .whitespaces)
        } else if parts.count == 1 {
            // Just the chat ID, need message from JSON
            chatId = parts[0].trimmingCharacters(in: .whitespaces)
        }
    }
    
    // Try JSON input file for missing values
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        print("Reading from JSON input file")
        if chatId == nil { chatId = json["chatId"] as? String }
        if message == nil { message = json["message"] as? String }
    }
    
    // Validate required fields
    guard let targetChatId = chatId, !targetChatId.isEmpty else {
        print("Error: Missing chatId")
        writeOutput(outputPath, success: false, error: "Missing chatId")
        return 1
    }
    
    guard let msg = message, !msg.isEmpty else {
        print("Error: Missing message")
        writeOutput(outputPath, success: false, error: "Missing message")
        return 1
    }
    
    print("Chat ID: \(targetChatId)")
    print("Message: \(msg)")
    
    // Connect to Messages
    guard let messages: MessagesApplication = SBApplication(bundleIdentifier: "com.apple.MobileSMS") else {
        print("Error: Could not connect to Messages app")
        writeOutput(outputPath, success: false, error: "Could not connect to Messages app")
        return 1
    }
    
    // Find the chat by ID
    guard let chats = messages.chats?() else {
        print("Error: Could not get chats")
        writeOutput(outputPath, success: false, error: "Could not get chats from Messages")
        return 1
    }
    
    var targetChat: MessagesChat? = nil
    var participants: [String] = []
    
    for i in 0..<chats.count {
        guard let chat = chats.object(at: i) as? MessagesChat else { continue }
        
        // Get the chat ID - it's an optional method
        let chatIdValue = chat.id?() ?? ""
        
        if chatIdValue.contains(targetChatId) || chatIdValue == targetChatId {
            targetChat = chat
            
            // Get participant names
            if let chatParticipants = chat.participants?() {
                for j in 0..<chatParticipants.count {
                    if let participant = chatParticipants.object(at: j) as? MessagesParticipant {
                        let name = participant.name ?? participant.fullName ?? participant.handle ?? "Unknown"
                        participants.append(name)
                    }
                }
            }
            break
        }
    }
    
    guard let chat = targetChat else {
        print("Error: Chat not found: \(targetChatId)")
        writeOutput(outputPath, success: false, error: "Chat not found: \(targetChatId)")
        return 1
    }
    
    // Send the message
    messages.send?(msg, to: chat)
    
    print("✓ Message sent to group: \(participants.joined(separator: ", "))")
    writeOutput(outputPath, success: true, chatId: targetChatId, message: msg, participants: participants)
    return 0
}

func writeOutput(_ path: String, success: Bool, error: String? = nil, chatId: String? = nil, message: String? = nil, participants: [String]? = nil) {
    var output: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        output["error"] = error
    }
    
    if success {
        if let chatId = chatId { output["chatId"] = chatId }
        if let message = message { output["message"] = message }
        if let participants = participants { output["participants"] = participants }
    }
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted) else { return }
    try? jsonData.write(to: URL(fileURLWithPath: path))
}