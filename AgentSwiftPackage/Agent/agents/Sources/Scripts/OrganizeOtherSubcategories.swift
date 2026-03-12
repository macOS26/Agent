import Foundation
import ScriptingBridgeCommon
import MailBridge

@main
struct OrganizeOtherSubcategories {
    static func main() {
        organizeOtherSubcategories()
    }
}

private let subcategoryNames = [
    "Legal", "RealEstate", "Automotive", "Entertainment", "Food",
    "Utilities", "Insurance", "Government", "NonProfit", "PetCare",
    "HomeServices", "Fitness", "Creative", "Marketing", "Support",
    "Notifications", "Security", "Cloud", "Career", "Misc"
]

private let subcategoryKeywords: [String: [String]] = [
    "Legal": ["legal", "attorney", "lawyer", "court", "contract", "agreement", "settlement", "lawsuit", "patent", "trademark", "copyright", "privacy", "terms", "legal@"],
    "RealEstate": ["home", "house", "rental", "apartment", "property", "mortgage", "real estate", "zillow", "realtor", "housing", "lease"],
    "Automotive": ["car", "auto", "vehicle", "dealer", "mechanic", "oil change", "dmv", "registration", "toyota", "honda", "ford", "bmw", "mercedes", "tesla", "service appointment"],
    "Entertainment": ["movie", "music", "concert", "ticket", "event", "show", "game", "gaming", "streaming", "netflix", "spotify", "apple music", "hulu", "disney", "hbo", "theater"],
    "Food": ["restaurant", "delivery", "food", "doordash", "ubereats", "grubhub", "reservation", "dining", "pizza", "order food"],
    "Utilities": ["electric", "water bill", "gas bill", "internet", "phone bill", "utility", "provider", "pg&e", "comcast", "att", "verizon", "spectrum"],
    "Insurance": ["insurance", "coverage", "policy", "claim", "premium", "deductible", "geico", "state farm", "allstate", "progressive", "blue cross", "united health"],
    "Government": ["irs", "tax", "government", "federal", "state", "social security", "medicare", "medicaid", "dmv", "passport", "uscis", "court notice"],
    "NonProfit": ["donation", "charity", "nonprofit", "volunteer", "cause", "fundraiser", "red cross", "united way", "salvation army"],
    "PetCare": ["pet", "vet", "dog", "cat", "animal", "grooming", "petco", "petsmart", "veterinary", "puppy", "kitten"],
    "HomeServices": ["cleaning", "landscaping", "pest", "plumbing", "electrician", "hvac", "repair", "handyman", "home service"],
    "Fitness": ["gym", "fitness", "workout", "exercise", "yoga", "trainer", "peloton", "classpass", "planet fitness", "la fitness"],
    "Creative": ["design", "creative", "art", "photography", "video", "editing", "canva", "adobe", "figma", "sketch"],
    "Marketing": ["marketing", "seo", "analytics", "campaign", "adwords", "ads", "mailchimp", "constant contact", "hubspot"],
    "Support": ["support", "help desk", "customer service", "feedback", "issue", "ticket", "troubleshoot"],
    "Notifications": ["notification", "alert", "reminder", "verify", "confirm", "verification", "automated"],
    "Security": ["password", "security", "login", "2fa", "authentication", "alert", "1password", "lastpass", "auth"],
    "Cloud": ["cloud", "storage", "backup", "sync", "drive", "dropbox", "icloud", "onedrive", "google drive", "box.com"],
    "Career": ["job", "career", "resume", "interview", "hiring", "recruiter", "linkedin", "indeed", "glassdoor", "ziprecruiter"]
]

private func categorizeEmail(subject: String, sender: String) -> String {
    let combined = (subject + " " + sender).lowercased()

    for (subcategory, keywords) in subcategoryKeywords {
        for keyword in keywords {
            if combined.contains(keyword) {
                return subcategory
            }
        }
    }
    return "Misc"
}

private func createMailbox(named name: String, in parentMailbox: String, accountName: String) -> Bool {
    let fullPath = "\(parentMailbox)/\(name)"

    let script = "tell application \"Mail\" to tell account \"\(accountName)\" to make new mailbox with properties {name:\"\(fullPath)\"}"

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]

    let pipe = Pipe()
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return true
        } else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("   ⚠️  Error creating \(name): \(error)")
            return false
        }
    } catch {
        print("   ⚠️  Exception creating \(name): \(error)")
        return false
    }
}

func organizeOtherSubcategories() {
    print("🗂️  Organizing 'Other' into Subcategories (ScriptingBridge)")
    print("============================================================")

    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("❌ Could not connect to Mail.app")
        return
    }

    guard let accounts = mail.accounts?() else {
        print("❌ Could not get accounts")
        return
    }

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

    guard let account = iCloudAccount else {
        print("❌ No iCloud account found")
        return
    }

    var otherMailbox: MailMailbox? = nil
    if let mailboxes = account.mailboxes?() {
        for i in 0..<mailboxes.count {
            if let mailbox = mailboxes.object(at: i) as? MailMailbox,
               let name = mailbox.name,
               name == "Other" {
                otherMailbox = mailbox
                break
            }
        }
    }

    guard let otherBox = otherMailbox else {
        print("❌ Could not find 'Other' mailbox")
        return
    }

    print("\n📁 Setting up subcategory mailboxes...")

    var subcategoryMailboxes: [String: MailMailbox] = [:]

    if let otherMailboxes = otherBox.mailboxes?() {
        print("   Found \(otherMailboxes.count) existing subfolders in Other")
        for i in 0..<otherMailboxes.count {
            if let mailbox = otherMailboxes.object(at: i) as? MailMailbox,
               let name = mailbox.name {
                subcategoryMailboxes[name] = mailbox
                print("   ✓ Found: \(name)")
            }
        }
    }

    for subName in subcategoryNames {
        if subcategoryMailboxes[subName] == nil {
            print("   Creating: \(subName)...")

            if createMailbox(named: subName, in: "Other", accountName: account.name ?? "") {
                Thread.sleep(forTimeInterval: 0.2)

                if let refreshedMailboxes = otherBox.mailboxes?() {
                    for i in 0..<refreshedMailboxes.count {
                        if let mb = refreshedMailboxes.object(at: i) as? MailMailbox,
                           let mbName = mb.name,
                           mbName == subName {
                            subcategoryMailboxes[subName] = mb
                            print("   ✅ Created: \(subName)")
                            break
                        }
                    }
                }
            }
        }
    }

    print("\n📧 Processing emails in 'Other'...")

    guard let messages = otherBox.messages?() else {
        print("❌ Could not access Other messages")
        return
    }

    let totalMessages = messages.count
    print("📬 Found \(totalMessages) messages in 'Other'")

    let batchSize = min(50, totalMessages)
    var movedCount = 0
    var errorCount = 0
    var categoryCounts: [String: Int] = [:]

    print("📝 Processing \(batchSize) messages...\n")

    for i in 0..<batchSize {
        guard let message = messages.object(at: i) as? MailMessage else { continue }

        let subject = message.subject ?? "No Subject"
        let sender = message.sender ?? "Unknown"

        let subcategory = categorizeEmail(subject: subject, sender: sender)

        if let targetMailbox = subcategoryMailboxes[subcategory] {
            message.moveTo?(targetMailbox as? SBObject)
            movedCount += 1
            categoryCounts[subcategory, default: 0] += 1

            let shortSubject = subject.count > 40 ? String(subject.prefix(40)) + "..." : subject
            print("   ✅ [\(subcategory)] \(shortSubject)")
        } else {
            if let miscMailbox = subcategoryMailboxes["Misc"] {
                message.moveTo?(miscMailbox as? SBObject)
                movedCount += 1
                categoryCounts["Misc", default: 0] += 1
                let shortSubject = subject.count > 40 ? String(subject.prefix(40)) + "..." : subject
                print("   📁 [Misc] \(shortSubject)")
            } else {
                errorCount += 1
                print("   ⚠️  No mailbox for: \(subcategory)")
            }
        }

        Thread.sleep(forTimeInterval: 0.02)
    }

    print("\n📊 Organization Summary:")
    print("========================")
    print("   Processed: \(batchSize)")
    print("   Moved: \(movedCount)")
    print("   Errors: \(errorCount)")

    print("\n📁 Subcategory Counts:")
    let sortedCounts = categoryCounts.sorted { $0.value > $1.value }
    for (cat, count) in sortedCounts {
        print("   \(cat): \(count)")
    }

    if let remaining = otherBox.messages?().count {
        print("\n📬 Remaining in 'Other': \(remaining)")
    }

    print("\n✨ Done! Run again to process more emails.")
}
