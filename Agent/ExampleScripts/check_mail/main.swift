import Foundation
import MailBridge

// Check Mail — shows unread count per account and inbox summary

guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
    print("Could not connect to Mail.app")
    exit(1)
}

print("Mail Status")
print("===========")

// Iterate accounts using element array pattern
guard let accounts = mail.accounts?() else {
    print("No accounts found")
    exit(0)
}

var totalUnread = 0

for i in 0..<accounts.count {
    guard let account = accounts.object(at: i) as? MailAccount,
          let name = account.name else { continue }

    // Each account has mailboxes with unreadCount
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

// Inbox message count
if let inbox = mail.inbox, let messages = inbox.messages?() {
    print("\nInbox: \(messages.count) messages")
}

print("\nTotal unread: \(totalUnread)")
