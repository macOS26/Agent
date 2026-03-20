import Foundation
import MailBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    checkMail()
    return 0
}

func checkMail() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/CheckMail_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/CheckMail_output.json"
    
    // Default options
    var showUnreadOnly = true
    var showAccountDetails = true
    var showInboxCount = true
    var outputJSON = false
    
    // Parse AGENT_SCRIPT_ARGS (format: key=value,key=value)
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "unreadOnly": showUnreadOnly = value.lowercased() == "true"
                case "accountDetails": showAccountDetails = value.lowercased() == "true"
                case "inboxCount": showInboxCount = value.lowercased() == "true"
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file for options
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let unread = json["unreadOnly"] as? Bool { showUnreadOnly = unread }
        if let details = json["accountDetails"] as? Bool { showAccountDetails = details }
        if let inbox = json["inboxCount"] as? Bool { showInboxCount = inbox }
        if let jsonOut = json["json"] as? Bool { outputJSON = jsonOut }
    }
    
    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("Could not connect to Mail.app")
        writeCheckMailOutput(outputPath, success: false, error: "Could not connect to Mail.app", outputJSON: outputJSON)
        return
    }

    print("Mail Status")
    print("===========")

    guard let accounts = mail.accounts?() else {
        print("No accounts found")
        writeCheckMailOutput(outputPath, success: false, error: "No accounts found", outputJSON: outputJSON)
        return
    }

    var totalUnread = 0
    var accountList: [[String: Any]] = []

    for i in 0..<accounts.count {
        guard let account = accounts.object(at: i) as? MailAccount,
              let name = account.name else { continue }

        var accountUnread = 0
        var mailboxList: [[String: Any]] = []
        
        if let mailboxes = account.mailboxes?() {
            for j in 0..<mailboxes.count {
                if let mb = mailboxes.object(at: j) as? MailMailbox {
                    let mbUnread = mb.unreadCount ?? 0
                    accountUnread += mbUnread
                    
                    if showAccountDetails {
                        mailboxList.append([
                            "name": mb.name ?? "",
                            "unread": mbUnread
                        ])
                    }
                }
            }
        }
        totalUnread += accountUnread
        
        if showAccountDetails || !showUnreadOnly {
            print("  \(name): \(accountUnread) unread")
        }
        
        accountList.append([
            "name": name,
            "unread": accountUnread,
            "mailboxes": mailboxList
        ])
    }

    if let inbox = mail.inbox, showInboxCount, let messages = inbox.messages?() {
        print("\nInbox: \(messages.count) messages")
    }

    print("\nTotal unread: \(totalUnread)")
    
    // Write JSON output if requested
    if outputJSON {
        writeCheckMailOutput(outputPath, success: true, accounts: accountList, totalUnread: totalUnread, outputJSON: true)
    }
}

func writeCheckMailOutput(_ path: String, success: Bool, error: String? = nil, accounts: [[String: Any]]? = nil, totalUnread: Int? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        result["error"] = error
    }
    
    if success {
        if let accounts = accounts { result["accounts"] = accounts }
        if let totalUnread = totalUnread { result["totalUnread"] = totalUnread }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\nJSON output: \(path)")
    }
}