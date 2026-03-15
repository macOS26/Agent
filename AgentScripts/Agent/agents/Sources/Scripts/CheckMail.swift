import Foundation
import MailBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    checkMail()
    return 0
}

func checkMail() {
    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("Could not connect to Mail.app")
        return
    }

    print("Mail Status")
    print("===========")

    guard let accounts = mail.accounts?() else {
        print("No accounts found")
        return
    }

    var totalUnread = 0

    for i in 0..<accounts.count {
        guard let account = accounts.object(at: i) as? MailAccount,
              let name = account.name else { continue }

        var accountUnread = 0
        if let mailboxes = account.mailboxes?() {
            for j in 0..<mailboxes.count {
                if let mb = mailboxes.object(at: j) as? MailMailbox {
                    accountUnread += mb.unreadCount ?? 0
                }
            }
        }
        totalUnread += accountUnread
        print("  \(name): \(accountUnread) unread")
    }

    if let inbox = mail.inbox, let messages = inbox.messages?() {
        print("\nInbox: \(messages.count) messages")
    }

    print("\nTotal unread: \(totalUnread)")
}
