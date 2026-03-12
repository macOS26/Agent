import Foundation
import ScriptingBridges

// MARK: - Email Categories

let categories = [
    "Work", "Finance", "Shopping", "Travel", "Social",
    "Health", "Education", "Technology", "News",
    "Personal", "Promotions", "Subscriptions", "Other"
]

// Category keywords for sorting
let categoryKeywords: [String: [String]] = [
    "Work": ["meeting", "project", "work", "business", "office", "team", "client", "deadline", "report"],
    "Finance": ["payment", "invoice", "bank", "bill", "statement", "paypal", "stripe", "transaction", "receipt", "refund"],
    "Shopping": ["order", "shipping", "delivery", "purchase", "amazon", "ebay", "tracking", "package", "shipped", "arrived"],
    "Travel": ["flight", "hotel", "booking", "reservation", "trip", "airline", "airbnb", "vacation", "itinerary"],
    "Social": ["facebook", "twitter", "instagram", "linkedin", "social", "friend", "connection", "follower"],
    "Health": ["appointment", "medical", "doctor", "health", "clinic", "prescription", "pharmacy", "hospital"],
    "Education": ["course", "class", "school", "university", "student", "learning", "tutorial", "webinar"],
    "Technology": ["software", "update", "app", "tech", "github", "download", "code", "developer", "api"],
    "News": ["newsletter", "news", "digest", "weekly", "monthly", "breaking", "update"],
    "Personal": ["family", "personal", "birthday", "anniversary", "wedding", "party"],
    "Promotions": ["sale", "deal", "promo", "offer", "discount", "limited time", "save", "clearance"],
    "Subscriptions": ["subscription", "unsubscribe", "mailing list", "opt-out"]
]

// MARK: - Helper Functions

func categorizeEmail(subject: String, sender: String) -> String {
    let subjectLower = subject.lowercased()
    let senderLower = sender.lowercased()

    for (category, keywords) in categoryKeywords {
        for keyword in keywords {
            if subjectLower.contains(keyword) || senderLower.contains(keyword) {
                return category
            }
        }
    }
    return "Other"
}

// MARK: - Main Script

print("Pure ScriptingBridge Email Organizer")
print("========================================")

guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
    print("Could not connect to Mail.app")
    exit(1)
}

// Get accounts
guard let accounts = mail.accounts?() else {
    print("Could not get accounts")
    exit(1)
}

print("Found \(accounts.count) mail accounts")

// Find iCloud account
var iCloudAccount: MailAccount? = nil
for i in 0..<accounts.count {
    if let account = accounts.object(at: i) as? MailAccount,
       let name = account.name,
       name.lowercased().contains("icloud") {
        iCloudAccount = account
        print("Using account: \(name)")
        break
    }
}

if iCloudAccount == nil {
    // Use first account as fallback
    if let firstAccount = accounts.object(at: 0) as? MailAccount,
       let name = firstAccount.name {
        iCloudAccount = firstAccount
        print("Using account: \(name)")
    }
}

guard let account = iCloudAccount else {
    print("No suitable account found")
    exit(1)
}

// MARK: - Create Mailboxes using ScriptingBridge

print("\nCreating mailboxes...")

// Get existing mailboxes
let existingMailboxes = account.mailboxes?()
var existingNames: Set<String> = []

if let mailboxes = existingMailboxes {
    for i in 0..<mailboxes.count {
        if let mailbox = mailboxes.object(at: i) as? MailMailbox,
           let name = mailbox.name {
            existingNames.insert(name)
        }
    }
}

// Create missing mailboxes (ScriptingBridge doesn't expose 'make new' so use AppleScript here)
for category in categories {
    if existingNames.contains(category) {
        print("   Exists: \(category)")
    } else {
        let script = """
        tell application "Mail"
            tell account "\(account.name ?? "")"
                try
                    make new mailbox with properties {name:"\(category)"}
                    return "Created: \(category)"
                on error
                    return "Failed: \(category)"
                end try
            end tell
        end tell
        """

        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        if let result = appleScript?.executeAndReturnError(&error) {
            print("   \(result.stringValue ?? "Created")")
        } else {
            print("   Failed: \(category)")
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

// MARK: - Process Emails using ScriptingBridge

print("\nProcessing emails...")

// Get inbox
guard let inbox = mail.inbox else {
    print("Could not access inbox")
    exit(1)
}

// Get messages from inbox
guard let messages = inbox.messages?() else {
    print("Could not access inbox messages")
    exit(1)
}

let totalMessages = messages.count
print("Inbox has \(totalMessages) messages")

// Build mailbox reference dictionary
var mailboxDict: [String: MailMailbox] = [:]

if let mailboxes = account.mailboxes?() {
    for i in 0..<mailboxes.count {
        if let mailbox = mailboxes.object(at: i) as? MailMailbox,
           let name = mailbox.name {
            mailboxDict[name] = mailbox
        }
    }
}

// Process up to 50 messages using ScriptingBridge moveTo
let batchSize = 50
var movedCount = 0
var errorCount = 0

let processCount = min(batchSize, totalMessages)
print("Processing \(processCount) messages...")

for i in 0..<processCount {
    guard let message = messages.object(at: i) as? MailMessage else { continue }

    guard let subject = message.subject,
          let sender = message.sender else { continue }

    let category = categorizeEmail(subject: subject, sender: sender)

    // Move using ScriptingBridge's moveTo method (from MailGenericMethods)
    if let targetMailbox = mailboxDict[category] {
        message.moveTo?(targetMailbox as? SBObject)
        movedCount += 1
        print("   [\(category)] \(subject.prefix(40))")
    } else {
        errorCount += 1
        print("   No mailbox for: \(category)")
    }

    Thread.sleep(forTimeInterval: 0.05)
}

print("\nProcessed: \(processCount) | Moved: \(movedCount) | Errors: \(errorCount)")

// MARK: - Show Summary using ScriptingBridge

print("\nMailbox Summary:")

if let mailboxes = account.mailboxes?() {
    for i in 0..<mailboxes.count {
        if let mailbox = mailboxes.object(at: i) as? MailMailbox,
           let name = mailbox.name,
           categories.contains(name) {
            let unread = mailbox.unreadCount ?? 0
            print("   \(name): \(unread) unread")
        }
    }
}

// Get remaining inbox count
if let remaining = inbox.messages?().count {
    print("\nInbox remaining: \(remaining) messages")
}

print("\nDone!")
