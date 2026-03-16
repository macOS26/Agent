import Foundation
import MailBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    fetchEmailAccounts()
    return 0
}

func fetchEmailAccounts() {
    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("Could not connect to Mail.app")
        return
    }

    print("📧 Email Accounts")
    print("=================\n")

    guard let accounts = mail.accounts?() else {
        print("No accounts found")
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
    }

    print("-------------------")
    print("Total: \(accountList.count) account(s)")

    // Write JSON output
    let home = NSHomeDirectory()
    let outputPath = "\(home)/Documents/Agent/email_accounts_output.json"
    let output: [String: Any] = [
        "accounts": accountList,
        "count": accountList.count
    ]

    if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted) {
        try? jsonData.write(to: URL(fileURLWithPath: outputPath))
        print("\n📄 JSON saved to: \(outputPath)")
    }
}