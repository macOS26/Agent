import Foundation
import MailBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    organizeEmails()
    return 0
}

private let categories = [
    "Work", "Finance", "Shopping", "Travel", "Social",
    "Health", "Education", "Technology", "News",
    "Personal", "Promotions", "Subscriptions"
]

private let categoryKeywords: [String: [String]] = [
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

private func categorizeEmail(subject: String, sender: String) -> String? {
    let subjectLower = subject.lowercased()
    let senderLower = sender.lowercased()

    for (category, keywords) in categoryKeywords {
        for keyword in keywords {
            if subjectLower.contains(keyword) || senderLower.contains(keyword) {
                return category
            }
        }
    }
    return nil
}

func organizeEmails() {
    print("📧 Organizing 'Other' Folder - Batch Loop Mode (100 per batch)")
    print("==============================================================")

    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("❌ Could not connect to Mail.app")
        return
    }

    guard let accounts = mail.accounts?() else {
        print("❌ Could not get accounts")
        return
    }

    print("📬 Found \(accounts.count) mail accounts")

    var iCloudAccount: MailAccount? = nil
    for i in 0..<accounts.count {
        if let account = accounts.object(at: i) as? MailAccount,
           let name = account.name,
           name.lowercased().contains("icloud") {
            iCloudAccount = account
            print("✅ Using account: \(name)")
            break
        }
    }

    if iCloudAccount == nil {
        if let firstAccount = accounts.object(at: 0) as? MailAccount,
           let name = firstAccount.name {
            iCloudAccount = firstAccount
            print("✅ Using account: \(name)")
        }
    }

    guard let account = iCloudAccount else {
        print("❌ No suitable account found")
        return
    }

    print("\n📧 Building mailbox references...")

    var mailboxDict: [String: MailMailbox] = [:]
    var otherMailbox: MailMailbox? = nil

    if let mailboxes = account.mailboxes?() {
        for i in 0..<mailboxes.count {
            if let mailbox = mailboxes.object(at: i) as? MailMailbox,
               let name = mailbox.name {
                mailboxDict[name] = mailbox
                if name == "Other" {
                    otherMailbox = mailbox
                }
            }
        }
    }

    print("✅ Found \(mailboxDict.count) mailboxes")

    guard let other = otherMailbox else {
        print("❌ Could not find 'Other' mailbox")
        return
    }

    guard let messages = other.messages?() else {
        print("❌ Could not access Other messages")
        return
    }

    let totalInOther = messages.count
    print("📬 'Other' mailbox has \(totalInOther) messages to process")

    let batchSize = 100
    var totalMoved = 0
    var totalErrors = 0
    var batchNumber = 0

    while true {
        batchNumber += 1

        guard let messages = other.messages?() else {
            print("❌ Could not access Other messages")
            break
        }

        let remainingCount = messages.count

        if remainingCount == 0 {
            print("\n🎉 All emails organized!")
            break
        }

        print("\n📬 Batch #\(batchNumber): \(remainingCount) emails remaining in 'Other'")

        let processCount = min(batchSize, remainingCount)
        print("📝 Processing \(processCount) messages...")

        var movedThisBatch = 0
        var stayedThisBatch = 0
        var errorsThisBatch = 0

        for i in 0..<processCount {
            guard let message = messages.object(at: i) as? MailMessage else { continue }

            guard let subject = message.subject,
                  let sender = message.sender else { continue }

            if let category = categorizeEmail(subject: subject, sender: sender) {
                if let targetMailbox = mailboxDict[category] {
                    message.moveTo?(targetMailbox as? SBObject)
                    movedThisBatch += 1
                } else {
                    errorsThisBatch += 1
                    print("   ⚠️  No mailbox for: \(category)")
                }
            } else {
                stayedThisBatch += 1
            }

            if (movedThisBatch + stayedThisBatch) % 10 == 0 {
                print("   📨 \(movedThisBatch + stayedThisBatch)/\(processCount) processed...")
            }

            Thread.sleep(forTimeInterval: 0.03)
        }

        totalMoved += movedThisBatch
        totalErrors += errorsThisBatch

        print("   ✅ Batch #\(batchNumber): Moved \(movedThisBatch), Stayed: \(stayedThisBatch), Errors: \(errorsThisBatch)")
        print("   📊 Total moved: \(totalMoved)")

        Thread.sleep(forTimeInterval: 0.5)
    }

    print("\n📊 Final Mailbox Summary:")

    if let mailboxes = account.mailboxes?() {
        for i in 0..<mailboxes.count {
            if let mailbox = mailboxes.object(at: i) as? MailMailbox,
               let name = mailbox.name,
               categories.contains(name) || name == "Other" {
                let unread = mailbox.unreadCount ?? 0
                print("   📁 \(name): \(unread) unread")
            }
        }
    }

    print("\n✨ Complete! Total organized: \(totalMoved) emails moved from 'Other'")
}
