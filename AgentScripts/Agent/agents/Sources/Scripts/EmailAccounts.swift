import Foundation
import MailBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    fetchEmailAccounts()
    return 0
}

func fetchEmailAccounts() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/EmailAccounts_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/EmailAccounts_output.json"
    
    // Default options
    var showDetails = true
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
                case "details": showDetails = value.lowercased() == "true"
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let details = json["details"] as? Bool { showDetails = details }
        if let jsonOut = json["json"] as? Bool { outputJSON = jsonOut }
    }
    
    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("Could not connect to Mail.app")
        writeEmailAccountsOutput(outputPath, success: false, error: "Could not connect to Mail.app", outputJSON: outputJSON)
        return
    }

    print("📧 Email Accounts")
    print("=================\n")

    guard let accounts = mail.accounts?() else {
        print("No accounts found")
        writeEmailAccountsOutput(outputPath, success: false, error: "No accounts found", outputJSON: outputJSON)
        return
    }

    var accountList: [[String: Any]] = []

    for i in 0..<accounts.count {
        guard let account = accounts.object(at: i) as? MailAccount else { continue }

        let name = account.name ?? "Unknown"
        let enabled = account.enabled ?? false
        let fullName = account.fullName ?? ""
        let userName = account.userName ?? ""
        let serverName = account.serverName ?? ""

        var emailAddresses: [String] = []
        if let addresses = account.emailAddresses as? [String] {
            emailAddresses = addresses
        }

        let accountType: String
        switch account.accountType {
        case .some(.imap):
            accountType = "IMAP"
        case .some(.pop):
            accountType = "POP"
        case .some(.iCloud):
            accountType = "iCloud"
        case .some(.smtp):
            accountType = "SMTP"
        default:
            accountType = "Unknown"
        }

        let accountInfo: [String: Any] = [
            "name": name,
            "type": accountType,
            "enabled": enabled,
            "fullName": fullName,
            "userName": userName,
            "server": serverName,
            "addresses": emailAddresses
        ]
        accountList.append(accountInfo)

        // Print to console
        if showDetails {
            print("📬 \(name)")
            print("   Type: \(accountType)")
            print("   Enabled: \(enabled ? "Yes" : "No")")
            if !fullName.isEmpty {
                print("   Full Name: \(fullName)")
            }
            if !userName.isEmpty {
                print("   Username: \(userName)")
            }
            if !serverName.isEmpty {
                print("   Server: \(serverName)")
            }
            if !emailAddresses.isEmpty {
                print("   Addresses: \(emailAddresses.joined(separator: ", "))")
            }
            print("")
        } else {
            print("📬 \(name) (\(accountType))")
        }
    }

    print("-------------------")
    print("Total: \(accountList.count) account(s)")
    
    // Write JSON output if requested
    if outputJSON {
        writeEmailAccountsOutput(outputPath, success: true, accounts: accountList, count: accountList.count, outputJSON: true)
    }
}

func writeEmailAccountsOutput(_ path: String, success: Bool, error: String? = nil, accounts: [[String: Any]]? = nil, count: Int? = nil, outputJSON: Bool) {
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
        if let count = count { result["count"] = count }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}