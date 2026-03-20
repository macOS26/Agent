import Foundation
import ScriptingBridgeCommon
import MailBridge

// ============================================================================
// OrganizeOtherSubcategories - Organize 'Other' mailbox into subcategories
//
// INPUT OPTIONS:
//   Option 1: AGENT_SCRIPT_ARGS environment variable
//     Format: "dryRun=true,limit=50,json=true"
//     Parameters:
//       - dryRun=true (preview without moving, default: false)
//       - limit=100 (max emails to process, default: all)
//       - json=true (output to JSON file)
//     Example: "dryRun=true,limit=50,json=true"
//
//   Option 2: JSON input file at ~/Documents/AgentScript/json/OrganizeOtherSubcategories_input.json
//     {
//       "dryRun": true,
//       "limit": 50,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/OrganizeOtherSubcategories_output.json
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    organizeOtherSubcategories()
    return 0
}

private let subcategoryNames = [
    "Legal", "RealEstate", "Automotive", "Entertainment", "Food",
    "Utilities", "Insurance", "Government", "NonProfit", "PetCare",
    "HomeServices", "Fitness", "Creative", "Marketing", "Support",
    "Notifications", "Security", "Cloud", "Career", "Shopping",
    "Finance", "Travel", "Education", "Health", "Social",
    "Technology", "News", "Dating", "Misc"
]

private let subcategoryKeywords: [String: [String]] = [
    "Legal": [
        "legal", "attorney", "lawyer", "court", "contract", "agreement", 
        "settlement", "lawsuit", "patent", "trademark", "copyright", "privacy",
        "terms", "legal@", "law firm", "litigation", "divorce", "estate",
        "will and trust", "probate", "notary", "deposition", "subpoena",
        "cease and desist", "class action", "infringement"
    ],
    "RealEstate": [
        "home", "house", "rental", "apartment", "property", "mortgage",
        "real estate", "zillow", "realtor", "housing", "lease", "landlord",
        "tenant", "property management", "open house", "listing", "homeowner",
        "down payment", "escrow", "home inspection", "appraisal", "refinance",
        "redfin", "trulia", "apartments.com", "zumper", "hotpads"
    ],
    "Automotive": [
        "car", "auto", "vehicle", "dealer", "mechanic", "oil change", "dmv",
        "registration", "toyota", "honda", "ford", "bmw", "mercedes", "tesla",
        "service appointment", "maintenance", "repair shop", "tire rotation",
        "brake service", "car wash", "autozone", "oreilly", "jiffy lube",
        "carfax", "auto loan", "car insurance", "lease", "roadside"
    ],
    "Entertainment": [
        "movie", "music", "concert", "ticket", "event", "show", "game", "gaming",
        "streaming", "netflix", "spotify", "apple music", "hulu", "disney",
        "hbo", "theater", "cinema", "fandango", "amc", "regal", "ticketmaster",
        "stubhub", "seatgeek", "gametime", "playstation", "xbox", "nintendo",
        "steam", "epic games", "twitch", "youtube premium", "paramount",
        "peacock", "prime video", "audible", "podcast"
    ],
    "Food": [
        "restaurant", "delivery", "food", "doordash", "ubereats", "grubhub",
        "reservation", "dining", "pizza", "order food", "takeout", "catering",
        "instacart", "groceries", "whole foods", "trader joe", "safeway",
        "costco", "kroger", "walmart grocery", "fresh direct", "hellofresh",
        "blue apron", "meal kit", "postmates", "seamless", "caviar",
        "open table", "resy", "yelp"
    ],
    "Utilities": [
        "electric", "water bill", "gas bill", "internet", "phone bill", "utility",
        "provider", "pg&e", "comcast", "att", "verizon", "spectrum", "xfinity",
        "cox", "centurylink", "t-mobile", "sprint", "dish", "directv",
        "garbage", "sewage", "municipal", "power company", "energy",
        "solar", "utility payment"
    ],
    "Insurance": [
        "insurance", "coverage", "policy", "claim", "premium", "deductible",
        "geico", "state farm", "allstate", "progressive", "blue cross",
        "united health", "aetna", "cigna", "humana", "kaiser", "metlife",
        "prudential", "liberty mutual", "farmers", "nationwide", "aaa",
        "life insurance", "health insurance", "auto insurance", "home insurance",
        "dental", "vision insurance"
    ],
    "Government": [
        "irs", "tax", "government", "federal", "state", "social security",
        "medicare", "medicaid", "dmv", "passport", "uscis", "court notice",
        "jury duty", "voting", "ballot", "election", "dmv", "irs", "ftb",
        "county", "city of", "state of", "department of", "treasury",
        "immigration", "citizenship", "veterans", "va ", "fema", "epa"
    ],
    "NonProfit": [
        "donation", "charity", "nonprofit", "volunteer", "cause", "fundraiser",
        "red cross", "united way", "salvation army", "goodwill", "habitat",
        "st. jude", "make-a-wish", "unicef", "doctors without borders",
        "aspca", "hsus", "wikipedia", "khan academy", "pbs", "npr",
        "charitable", "tax deductible", "501(c)"
    ],
    "PetCare": [
        "pet", "vet", "dog", "cat", "animal", "grooming", "petco", "petsmart",
        "veterinary", "puppy", "kitten", "furry", "adoption", "spay", "neuter",
        "rabies", "flea", "tick", "heartworm", "pet food", "pet insurance",
        "chewy", "pet meds", "animal hospital", "kennel", "boarding"
    ],
    "HomeServices": [
        "cleaning", "landscaping", "pest", "plumbing", "electrician", "hvac",
        "repair", "handyman", "home service", "lawn", "garden", "pool",
        "roofing", "painting", "carpet", "mover", "moving", "storage",
        "home depot", "lowes", "taskrabbit", "angie's list", "homeadvisor",
        "thumbtack", "housecall", "terminix", "orkin"
    ],
    "Fitness": [
        "gym", "fitness", "workout", "exercise", "yoga", "trainer", "peloton",
        "classpass", "planet fitness", "la fitness", "gold's gym", "equinox",
        "crossfit", "orange theory", "f45", "anytime fitness", "24 hour",
        "personal training", "spin", "pilates", "barre", "hiit", "weights",
        "treadmill", "myfitnesspal", "fitbit", "apple watch fitness"
    ],
    "Creative": [
        "design", "creative", "art", "photography", "video", "editing",
        "canva", "adobe", "figma", "sketch", "illustrator", "photoshop",
        "lightroom", "premiere", "final cut", "davinci", "blender",
        "shutterstock", "getty images", "unsplash", "pexels", "etsy shop",
        "craft", "diy project"
    ],
    "Marketing": [
        "marketing", "seo", "analytics", "campaign", "adwords", "ads",
        "mailchimp", "constant contact", "hubspot", "salesforce", "zendesk",
        " CRM", "newsletter", "email campaign", "landing page", "landing",
        "convertkit", "activecampaign", "klaviyo", "intercom", "drift"
    ],
    "Support": [
        "support", "help desk", "customer service", "feedback", "issue",
        "ticket", "troubleshoot", "help center", "faq", "contact us",
        "customer care", "technical support", "it support", "service desk"
    ],
    "Notifications": [
        "notification", "alert", "reminder", "verify", "confirm", "verification",
        "automated", "system", "noreply", "no-reply", "do not reply",
        "automated message", "action required", "update available"
    ],
    "Security": [
        "password", "security", "login", "2fa", "authentication", "alert",
        "1password", "lastpass", "auth", "bitwarden", "dashlane", "keeper",
        "two-factor", "verification code", "security alert", "breach",
        "suspicious activity", "account security", "login attempt"
    ],
    "Cloud": [
        "cloud", "storage", "backup", "sync", "drive", "dropbox", "icloud",
        "onedrive", "google drive", "box.com", "backblaze", "carbonite",
        "pcloud", "mega", "sync.com", "sharepoint"
    ],
    "Career": [
        "job", "career", "resume", "interview", "hiring", "recruiter",
        "linkedin", "indeed", "glassdoor", "ziprecruiter", "monster",
        "careerbuilder", "handshake", "angel.co", "hired", "dice",
        "cover letter", "job application", "position", "opportunity",
        "salary", "compensation", "benefits", "offer letter"
    ],
    "Shopping": [
        "order", "shipping", "delivery", "tracking", "amazon", "ebay", "walmart",
        "target", "best buy", "costco", "wayfair", "etsy", "shopify store",
        "purchase", "checkout", "cart", "confirmation", "shipped", "package",
        "ups", "fedex", "usps", "dhl", "ontrac", "lasership", "tracking number",
        "out for delivery", "arriving", "delivered", "return", "refund",
        "shein", "temu", "wish"
    ],
    "Finance": [
        "bank", "credit", "debit", "payment", "invoice", "receipt", "transaction",
        "balance", "statement", "chase", "bank of america", "wells fargo", "citi",
        "capital one", "discover", "amex", "american express", "paypal",
        "venmo", "zelle", "cash app", "chime", "ally", "robinhood", "fidelity",
        "vanguard", "schwab", "etrade", "investment", "retirement", "401k",
        "ira", "stock", "crypto", "coinbase", "binance", "kraken"
    ],
    "Travel": [
        "flight", "hotel", "booking", "reservation", "airline", "vacation",
        "travel", "trip", "expedia", "booking.com", "airbnb", "vrbo",
        "kayak", "priceline", "hotels.com", "tripadvisor", "hotwire",
        "southwest", "delta", "united", "american airlines", "jetblue",
        "spirit", "frontier", "alaska", "hertz", "enterprise", "budget",
        "rental car", "cruise", "resort", "lounge", "passport", "visa"
    ],
    "Education": [
        "school", "university", "college", "course", "class", "learning",
        "education", "student", "teacher", "professor", "enrollment",
        "degree", "diploma", "transcript", "tuition", "financial aid",
        "scholarship", "coursera", "udemy", "edx", "khan academy", "skillshare",
        "linkedin learning", "duolingo", "masterclass", "pluralsight"
    ],
    "Health": [
        "doctor", "appointment", "medical", "health", "hospital", "clinic",
        "pharmacy", "prescription", "telehealth", "telemedicine", "dental",
        "vision", "wellness", "therapy", "mental health", "counseling",
        "lab results", "test results", "cvs pharmacy", "walgreens", "rite aid",
        "goodrx", "zocdoc", "healthgrades", "mychart", "epic patient"
    ],
    "Social": [
        "facebook", "instagram", "twitter", "tiktok", "snapchat", "linkedin",
        "pinterest", "reddit", "discord", "slack", "teams", "whatsapp",
        "telegram", "messenger", "messaging", "friend request", "profile",
        "social media", "post", "like", "comment", "share", "follow"
    ],
    "Technology": [
        "software", "hardware", "computer", "laptop", "phone", "tablet",
        "apple", "microsoft", "google", "samsung", "dell", "hp", "lenovo",
        "asus", "acer", "windows", "macos", "ios", "android", "app",
        "update", "upgrade", "install", "download", "bug", "feature",
        "github", "gitlab", "stackoverflow", "stack overflow"
    ],
    "News": [
        "news", "breaking", "headline", "article", "story", "report",
        "nytimes", "new york times", "washington post", "wall street journal",
        "cnn", "bbc", "npr", "reuters", "associated press", "ap news",
        "fox news", "nbc", "cbs", "abc news", "usa today", "la times",
        "newsletter", "daily digest"
    ],
    "Dating": [
        "dating", "match", "tinder", "bumble", "hinge", "okcupid", "plenty",
        "match.com", "eharmony", "coffee meets", "zoosk", "her", "grindr",
        "profile views", "new matches", "someone liked"
    ]
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
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/OrganizeOtherSubcategories_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/OrganizeOtherSubcategories_output.json"
    
    // Parse AGENT_SCRIPT_ARGS
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var dryRun = false
    var limit: Int? = nil
    var outputJSON = false
    
    if !argsString.isEmpty {
        let pairs = argsString.components(separatedBy: ",")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                switch key {
                case "dryRun", "dry": dryRun = value.lowercased() == "true"
                case "limit": limit = Int(value)
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let d = json["dryRun"] as? Bool { dryRun = d }
        if let l = json["limit"] as? Int { limit = l }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    print("🗂️  Organizing 'Other' into Subcategories")
    print("═══════════════════════════════════════")
    print("Dry run: \(dryRun ? "Yes" : "No")")
    if let l = limit { print("Limit: \(l) emails") }
    print("")

    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("❌ Could not connect to Mail.app")
        writeOutput(outputPath, success: false, error: "Could not connect to Mail.app", outputJSON: outputJSON)
        return
    }

    guard let accounts = mail.accounts?() else {
        print("❌ Could not get accounts")
        writeOutput(outputPath, success: false, error: "Could not get accounts", outputJSON: outputJSON)
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
        writeOutput(outputPath, success: false, error: "No iCloud account found", outputJSON: outputJSON)
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
        writeOutput(outputPath, success: false, error: "Could not find 'Other' mailbox", outputJSON: outputJSON)
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

    // Create missing subcategory mailboxes
    if !dryRun {
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

        // Ensure Misc mailbox exists as fallback
        if subcategoryMailboxes["Misc"] == nil {
            print("   Creating fallback: Misc...")
            if createMailbox(named: "Misc", in: "Other", accountName: account.name ?? "") {
                Thread.sleep(forTimeInterval: 0.2)
                if let refreshedMailboxes = otherBox.mailboxes?() {
                    for i in 0..<refreshedMailboxes.count {
                        if let mb = refreshedMailboxes.object(at: i) as? MailMailbox,
                           let mbName = mb.name,
                           mbName == "Misc" {
                            subcategoryMailboxes["Misc"] = mb
                            print("   ✅ Created fallback: Misc")
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
        writeOutput(outputPath, success: false, error: "Could not access Other messages", outputJSON: outputJSON)
        return
    }

    let totalMessages = messages.count
    print("📬 Found \(totalMessages) messages in 'Other'")

    if totalMessages == 0 {
        print("✅ No messages to process!")
        writeOutput(outputPath, success: true, processed: 0, moved: 0, dryRun: dryRun, outputJSON: outputJSON)
        return
    }

    let processCount = limit != nil ? min(limit!, totalMessages) : totalMessages
    var movedCount = 0
    var errorCount = 0
    var categoryCounts: [String: Int] = [:]

    print("📝 Processing \(processCount) messages...\n")

    for i in 0..<processCount {
        guard let message = messages.object(at: i) as? MailMessage else { continue }

        let subject = message.subject ?? "No Subject"
        let sender = message.sender ?? "Unknown"

        let subcategory = categorizeEmail(subject: subject, sender: sender)

        // Get target mailbox - always fallback to Misc if category not found
        let targetMailbox: MailMailbox?
        if let mb = subcategoryMailboxes[subcategory] {
            targetMailbox = mb
        } else if let miscMb = subcategoryMailboxes["Misc"] {
            targetMailbox = miscMb
        } else {
            targetMailbox = nil
        }

        if let target = targetMailbox {
            if dryRun {
                print("   [DRY RUN] Would move to [\(subcategory)]: \(subject.prefix(50))...")
            } else {
                message.moveTo?(target as? SBObject)
                print("   ✅ [\(subcategory)] \(subject.prefix(50))...")
            }
            movedCount += 1
            categoryCounts[subcategory, default: 0] += 1
        } else {
            errorCount += 1
            print("   ⚠️  No mailbox available for: \(subcategory)")
        }

        Thread.sleep(forTimeInterval: 0.03)
    }

    print("\n📊 Organization Summary:")
    print("═══════════════════════════════════════")
    print("   Processed: \(processCount)")
    print("   \(dryRun ? "Would move" : "Moved"): \(movedCount)")
    print("   Errors: \(errorCount)")

    print("\n📁 Subcategory Counts:")
    let sortedCounts = categoryCounts.sorted { $0.value > $1.value }
    for (cat, count) in sortedCounts {
        print("   \(cat): \(count)")
    }

    if let remaining = otherBox.messages?().count {
        print("\n📬 Remaining in 'Other': \(remaining)")
    }

    if dryRun {
        print("\n⚠️ Dry run - no emails were actually moved")
    }

    print("\n✨ Done!")
    
    // Write JSON output if requested
    if outputJSON {
        writeFullOutput(outputPath, success: true, processed: processCount, moved: movedCount, errors: errorCount, categoryCounts: categoryCounts, dryRun: dryRun)
    }
}

func writeOutput(_ path: String, success: Bool, error: String?, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if let error = error {
        result["error"] = error
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}

func writeOutput(_ path: String, success: Bool, processed: Int, moved: Int, dryRun: Bool, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "dryRun": dryRun,
        "processed": processed,
        "moved": moved
    ]
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}

func writeFullOutput(_ path: String, success: Bool, processed: Int, moved: Int, errors: Int, categoryCounts: [String: Int], dryRun: Bool) {
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "dryRun": dryRun,
        "processed": processed,
        "moved": moved,
        "errors": errors,
        "categoryCounts": categoryCounts
    ]
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}