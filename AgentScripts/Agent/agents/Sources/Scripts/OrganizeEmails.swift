import Foundation
import MailBridge

// ============================================================================
// OrganizeEmails - Organize inbox emails into folders by content
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
//   Option 2: JSON input file at ~/Documents/AgentScript/json/OrganizeEmails_input.json
//     {
//       "dryRun": true,
//       "limit": 50,
//       "json": true
//     }
//
// OUTPUT: ~/Documents/AgentScript/json/OrganizeEmails_output.json
// ============================================================================

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    organizeEmails()
    return 0
}

// Common folder name variations and their matching keywords
private let folderKeywords: [String: [String]] = [
    // Work & Business
    "Work": ["work", "meeting", "project", "business", "office", "team", "client", "deadline", "report", "boss", "colleague", "coworker", "agenda", "conference", "presentation", "spreadsheet", "proposal", "contract", "contractor", "consultant"],
    "Business": ["business", "company", "corporate", "enterprise", "b2b", "partnership", "stakeholder", "executive", "ceo", "cfo", "manager", "director"],
    
    // Finance
    "Finance": ["finance", "financial", "investment", "portfolio", "trading", "stock", "broker", "dividend", "etf", "mutual fund", "401k", "ira", "retirement", "wealth", "asset", "equity", "bond"],
    "Banking": ["bank", "banking", "checking", "savings", "wire", "transfer", "deposit", "withdrawal", "chase", "wells fargo", "citi", "bank of america", "capital one", "credit union", "routing", "account number"],
    "Bills": ["bill", "payment due", "invoice", "statement", "due date", "payment reminder", "autopay", "balance due", "amount due", "payment received", "receipt", "billing"],
    "Taxes": ["tax", "irs", "w2", "w4", "1099", "tax return", "taxes", "tax season", "refund", "deduction", "taxable", "filing", "turbotax", "hr block"],
    "Money": ["money", "cash", "funds", "payment", "pay", "paid", "balance", "transaction"],
    "Credit": ["credit", "credit card", "visa", "mastercard", "amex", "discover", "credit score", "fico", "credit report", "credit limit", "apr", "interest rate"],
    
    // Shopping
    "Shopping": ["order", "purchase", "cart", "checkout", "buy", "bought", "store", "shop", "retail", "merchant"],
    "Amazon": ["amazon", "amzn", "prime", "amazon prime", "alexa", "kindle", "echo", "fire tv", "amazon web services", "aws"],
    "Orders": ["order confirmation", "shipping", "delivery", "tracking", "package", "dispatched", "shipped", "out for delivery", "delivered", "order status", "tracking number", "usps", "ups", "fedex", "dhl"],
    "Deals": ["deal", "sale", "discount", "offer", "clearance", "limited time", "promo code", "coupon", "save", "off", "best price", "flash sale", "deal of the day"],
    "eBay": ["ebay", "auction", "bid", "seller", "buyer", "listing"],
    "Etsy": ["etsy", "handmade", "vintage", "craft", "artisan"],
    
    // Travel
    "Travel": ["travel", "trip", "vacation", "journey", "destination", "adventure", "explore", "tour", "tourism", "tourist"],
    "Flights": ["flight", "airline", "boarding", "departure", "arrival", "gate", "airport", "plane", "booking", "itinerary", "southwest", "delta", "united", "american airlines", "jetblue", "spirit", "frontier", "alaska", "booking.com", "expedia", "kayak", "priceline"],
    "Hotels": ["hotel", "reservation", "booking", "check-in", "checkout", "room", "accommodation", "lodge", "resort", "airbnb", "vrbo", "marriott", "hilton", "hyatt", "holiday inn", "sheraton", "westin", "wyndham"],
    "Cars": ["rental car", "car rental", "hertz", "avis", "enterprise", "budget", "national", "alamo", "thrifty", "rental", "vehicle"],
    "Uber": ["uber", "lyft", "ride", "ride share", "driver"],
    
    // Health
    "Health": ["health", "medical", "doctor", "hospital", "clinic", "patient", "appointment", "checkup", "wellness", "healthy", "healthcare", "physician", "nurse", "specialist"],
    "Medical": ["medical", "patient", "diagnosis", "treatment", "prescription", "medicine", "medication", "rx", "pharmacy", "cvs", "walgreens", "lab", "test results", "x-ray", "mri", "scan", "surgery", "procedure"],
    "Fitness": ["gym", "fitness", "workout", "exercise", "yoga", "trainer", "peloton", "crossfit", "fitness", "weight", "weights", "cardio", "training", "personal trainer", "strength", "endurance"],
    "Dental": ["dental", "dentist", "teeth", "tooth", "orthodontist", "cleaning", "cavity", "root canal", "crown", "braces", "invisalign"],
    "Vision": ["vision", "eye", "optometrist", "glasses", "contacts", "eye exam", "optical", "eye doctor", "lasik"],
    "MentalHealth": ["therapy", "therapist", "counseling", "mental health", "psychology", "psychiatrist", "anxiety", "depression", "counselor", "session"],
    
    // Social
    "Social": ["social", "facebook", "twitter", "instagram", "linkedin", "tiktok", "snapchat", "pinterest", "reddit", "social media", "messenger", "whatsapp", "telegram", "discord"],
    "Friends": ["friend", "buddy", "hangout", "catch up", "party", "get together", "birthday", "celebration", "invitation", "invite"],
    "Family": ["family", "mom", "dad", "sister", "brother", "kids", "children", "son", "daughter", "parent", "spouse", "husband", "wife", "grandparent", "cousin", "niece", "nephew", "aunt", "uncle"],
    "Dating": ["dating", "match", "tinder", "bumble", "hinge", "okcupid", "date", "relationship", "singles"],
    
    // Technology
    "Technology": ["tech", "software", "hardware", "app", "download", "update", "version", "device", "gadget", "smartphone", "laptop", "computer", "tablet", "iphone", "android", "mac", "windows", "linux"],
    "GitHub": ["github", "repository", "pull request", "commit", "code", "git", "branch", "merge", "clone", "push", "issue", "pr", "fork"],
    "Development": ["developer", "api", "sdk", "code", "programming", "coding", "software engineer", "web dev", "mobile dev", "backend", "frontend", "full stack", "devops", "agile", "scrum", "sprint", "jira", "confluence"],
    "Apple": ["apple", "iphone", "ipad", "macbook", "imac", "apple watch", "airpods", "icloud", "app store", "itunes", "apple id", "apple music", "apple tv", "apple pay"],
    "Google": ["google", "gmail", "google drive", "google docs", "google sheets", "google calendar", "google maps", "youtube", "google play", "google cloud", "android"],
    "Microsoft": ["microsoft", "windows", "office", "outlook", "word", "excel", "powerpoint", "onedrive", "teams", "azure", "surface", "xbox"],
    
    // Education
    "Education": ["education", "school", "university", "college", "course", "class", "student", "teacher", "professor", "lecture", "exam", "test", "homework", "assignment", "grade", "degree", "diploma", "semester", "tuition", "enrollment", "admission", "academic"],
    "Learning": ["learning", "tutorial", "webinar", "training", "certification", "course", "lesson", "workshop", "seminar", "education", "skill", "udemy", "coursera", "edx", "linkedin learning", "skillshare", "masterclass"],
    "Courses": ["course", "lesson", "module", "curriculum", "enrollment", "syllabus", "quiz", "certificate", "completion"],
    
    // News & Media
    "News": ["news", "newsletter", "digest", "headline", "breaking", "daily", "weekly", "update", "current events", "politics", "world news", "local news", "national news", " cnn", "bbc", "npr", "reuters", "associated press"],
    "Media": ["media", "video", "audio", "podcast", "streaming", "youtube", "vimeo", "spotify", "soundcloud", "twitch", "stream"],
    "Entertainment": ["entertainment", "movie", "music", "game", "gaming", "netflix", "hulu", "disney", "hbo", "amazon prime video", "apple tv+", "showtime", "paramount", "peacock", "spotify", "tidal", "deezer", "concert", "theater", "comedy"],
    "Sports": ["sports", "game", "score", "team", "player", "nfl", "nba", "mlb", "nhl", "soccer", "football", "basketball", "baseball", "hockey", "tennis", "golf", "espn", "athletic"],
    
    // Personal
    "Personal": ["personal", "private", "confidential", "important", "note", "reminder"],
    "Important": ["important", "urgent", "critical", "action required", "attention", "immediate", "deadline", "asap", "priority"],
    
    // Subscriptions
    "Subscriptions": ["subscription", "unsubscribe", "newsletter", "mailing list", "opt-out", "opt out", "preferences", "subscription renewal", "billing cycle", "recurring", "monthly subscription", "annual subscription"],
    "Newsletters": ["newsletter", "weekly", "monthly", "digest", "update", "bulletin", "circular", "email list"],
    
    // Promotions
    "Promotions": ["promo", "promotion", "sale", "discount", "coupon", "voucher", "special offer", "limited time", "exclusive", "save up to", "off your", "free shipping", "best deal", "clearance", "blowout", "flash sale", "black friday", "cyber monday"],
    "Marketing": ["marketing", "campaign", "advertisement", "sponsored", "ad", "brand", "promotion", "launch", "new product", "brand new", "introducing"],
    "Spam": ["spam", "winner", "lottery", "prize", "click here", "act now", "congratulations", "limited time offer", "you've been selected", "claim your", "urgent attention", "act immediately"],
    
    // Security
    "Security": ["security", "password", "2fa", "authentication", "verify", "verification", "login", "sign in", "account security", "two-factor", "mfa", "otp", "one-time password", "security alert", "suspicious activity", "breach", "hack"],
    "Alerts": ["alert", "warning", "notification", "critical", "immediate", "attention required", "security alert", "system alert", "important notice"],
    
    // Legal
    "Legal": ["legal", "attorney", "lawyer", "court", "lawsuit", "contract", "agreement", "settlement", "litigation", "law firm", "sue", "legal action", "subpoena", "deposition", "trial", "judge", "rights", "intellectual property", "patent", "trademark", "copyright"],
    
    // Real Estate
    "RealEstate": ["real estate", "property", "mortgage", "zillow", "realtor", "house", "apartment", "home buying", "home selling", "listing", "open house", "offer", "closing", "escrow", "home inspection", "down payment", "refinance", "home loan", "redfin", "trulia", "century 21", "coldwell", "remax", "kw", "keller williams"],
    "Property": ["property", "investment property", "rental property", "landlord", "tenant", "lease", "rent", "property management", "hoa", "condo", "townhouse", "duplex", "multi-family"],
    
    // Automotive
    "Automotive": ["car", "auto", "vehicle", "mechanic", "oil change", "service", "dealer", "dealership", "maintenance", "repair", "tire", "brake", "engine", "transmission", "inspection", "registration", "dmv", "license plate", "auto insurance", "car insurance", "tesla", "ford", "toyota", "honda", "chevrolet", "bmw", "mercedes"],
    
    // Food & Dining
    "Food": ["food", "restaurant", "delivery", "doordash", "ubereats", "grubhub", "pizza", "takeout", "order food", "menu", "dinner", "lunch", "breakfast", "brunch", "catering", "meal", "recipe", "grocery", "instacart", "fresh", "meal kit", "hello fresh", "blue apron", "groceries", "supermarket", "whole foods", "trader joe", "costco", "walmart", "kroger", "safeway", "albertsons", "publix", "target"],
    "Dining": ["dining", "reservation", "table", "restaurant", "opentable", "resy", "yelp", "review", "star", "rating"],
    
    // Home
    "Home": ["home", "house", "apartment", "rent", "landlord", "tenant", "mortgage", "property", "homeowner", "lease", "rental", "housing", "condo", "studio", "bedroom", "bathroom"],
    "Utilities": ["utility", "electric", "water", "gas", "internet", "phone bill", "power", "energy", "pg&e", "con edison", "duke energy", "spectrum", "comcast", "xfinity", "att", "verizon", "t-mobile", "sprint", "wifi", "broadband", "cable", "satellite"],
    "HomeImprovement": ["home improvement", "renovation", "remodel", "repair", "diy", "lowes", "home depot", "menards", "ace hardware", "furniture", "decor", "landscaping", "hvac", "plumbing", "electrical", "roofing", "painting", "flooring", "appliance"],
    
    // Insurance
    "Insurance": ["insurance", "coverage", "policy", "claim", "premium", "deductible", "insurer", "provider", "geico", "state farm", "allstate", "progressive", "liberty mutual", "usaa", "farmers", "nationwide", "aetna", "cigna", "united health", "blue cross", "blue shield", "anthem", "health insurance", "auto insurance", "home insurance", "life insurance"],
    
    // Government
    "Government": ["government", "irs", "tax", "dmv", "social security", "passport", "federal", "state", "county", "city", "municipal", "court", "department", "agency", "bureau", "medicare", "medicaid", "va", "veterans", "uscis", "immigration", "census", "vote", "election", "voter registration"],
    "DMV": ["dmv", "department of motor vehicles", "driver license", "driver's license", "license renewal", "vehicle registration", "car registration", "title", "vin", "plate"],
    
    // Career
    "Career": ["job", "career", "resume", "interview", "hiring", "recruiter", "employment", "position", "opportunity", "salary", "offer", "benefits", "cover letter", "linkedin", "indeed", "glassdoor", "ziprecruiter", "monster", "careerbuilder", "handshake", "job application", "job search", "job alert", "new job", "job posting"],
    "Jobs": ["job", "position", "opening", "application", "employer", "work", "employment", "hiring now", "immediate opening", "full-time", "part-time", "remote", "hybrid", "onsite"],
    
    // Cloud & Storage
    "Cloud": ["cloud", "storage", "backup", "sync", "drive", "dropbox", "icloud", "onedrive", "google drive", "box", "sync", "upload", "download", "cloud storage", "file sharing"],
    
    // Support
    "Support": ["support", "help", "ticket", "customer service", "troubleshoot", "technical support", "customer care", "contact us", "help desk", "issue", "problem", "bug", "feature request", "feedback"],
    
    // Notifications
    "Notifications": ["notification", "alert", "reminder", "automated", "system", "automated message", "do not reply", "no-reply", "noreply"],
    
    // Religion & Spirituality
    "Religion": ["church", "temple", "mosque", "synagogue", "prayer", "worship", "faith", "religious", "spiritual", "god", "bible", "prayer", "ministry", "pastor", "priest", "rabbi", "imam", "meditation"],
    
    // Hobbies & Interests  
    "Hobbies": ["hobby", "crafts", "photography", "art", "music", "instrument", "painting", "drawing", "writing", "reading", "gardening", "cooking", "baking", "knitting", "woodworking", "fishing", "hunting", "camping", "hiking", "cycling", "running"],
    "Pets": ["pet", "dog", "cat", "puppy", "kitten", "veterinarian", "vet", "animal", "pet care", "pet food", "grooming", "adoption", "rescue", "petco", "petsmart", "chewy"],
    "Gaming": ["game", "gaming", "video game", "playstation", "xbox", "nintendo", "steam", "twitch", "esports", "gamer", "multiplayer", "online game", "mobile game", "puzzle", "rpg", "fps", "mmorpg"],
    
    // Volunteering & Charity
    "Charity": ["charity", "donate", "donation", "nonprofit", "volunteer", "fundraiser", "cause", "foundation", "organization", "campaign", "support", "help", "give", "giving", "philanthropy"],
    
    // Misc
    "Misc": ["miscellaneous", "general", "other"],
    "Other": ["other", "misc", "general", "uncategorized"]
]

// Calculate match score for a folder
private func matchScore(subject: String, sender: String, folderName: String) -> Int {
    let subjectLower = subject.lowercased()
    let senderLower = sender.lowercased()
    let folderLower = folderName.lowercased()
    var score = 0
    
    // Direct folder name match in subject/sender (very strong match)
    if subjectLower.contains(folderLower) { score += 10 }
    if senderLower.contains(folderLower) { score += 8 }
    
    // Check if folder name appears as a word (not just substring)
    let subjectWords = subjectLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
    let senderWords = senderLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
    
    if subjectWords.contains(folderLower) { score += 8 }
    if senderWords.contains(folderLower) { score += 6 }
    
    // Keyword matching - keywords associated with this folder
    if let keywords = folderKeywords[folderName] {
        for keyword in keywords {
            let keywordLower = keyword.lowercased()
            if subjectLower.contains(keywordLower) { score += 4 }
            if senderLower.contains(keywordLower) { score += 3 }
            
            // Bonus for exact word match of keyword
            if subjectWords.contains(keywordLower) { score += 2 }
            if senderWords.contains(keywordLower) { score += 1 }
        }
    }
    
    return score
}

// Find best matching folder for an email
private func findBestFolder(subject: String, sender: String, availableFolders: [String]) -> String? {
    var bestFolder: String? = nil
    var bestScore = 0
    let minScore = 2  // Lowered threshold for better matching
    
    for folder in availableFolders {
        // Skip special folders
        let folderLower = folder.lowercased()
        if ["inbox", "sent", "drafts", "trash", "junk", "spam", "archive", "deleted", "other"].contains(folderLower) {
            continue  // Don't match "Other" here - it's a fallback
        }
        
        let score = matchScore(subject: subject, sender: sender, folderName: folder)
        if score > bestScore && score >= minScore {
            bestScore = score
            bestFolder = folder
        }
    }
    
    // Fallback to "Other" if no match found and "Other" folder exists
    if bestFolder == nil && availableFolders.contains(where: { $0.lowercased() == "other" }) {
        return availableFolders.first { $0.lowercased() == "other" }
    }
    
    return bestFolder
}

func organizeEmails() {
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/OrganizeEmails_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/OrganizeEmails_output.json"
    
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
    
    print("📧 Dynamic Email Organizer")
    print("═══════════════════════════════════════")
    print("Dry run: \(dryRun ? "Yes" : "No")")
    if let l = limit { print("Limit: \(l) emails") }
    print("")
    
    guard let mail: MailApplication = SBApplication(bundleIdentifier: "com.apple.mail") else {
        print("❌ Could not connect to Mail.app")
        writeOutput(outputPath, success: false, error: "Could not connect to Mail.app", outputJSON: outputJSON)
        return
    }
    
    // Discover email accounts
    guard let accounts = mail.accounts?() else {
        print("❌ Could not get accounts")
        writeOutput(outputPath, success: false, error: "Could not get accounts", outputJSON: outputJSON)
        return
    }
    
    print("📬 Discovering Email Accounts...")
    
    var discoveredAccounts: [(account: MailAccount, name: String, isEnabled: Bool)] = []
    
    for i in 0..<accounts.count {
        guard let account = accounts.object(at: i) as? MailAccount,
              let name = account.name else { continue }
        
        let enabled = account.enabled ?? false
        
        let accountType: String
        switch account.accountType {
        case .some(.imap): accountType = "IMAP"
        case .some(.pop): accountType = "POP"
        case .some(.iCloud): accountType = "iCloud"
        case .some(.smtp): accountType = "SMTP"
        default: accountType = "Unknown"
        }
        
        print("   📥 \(name) (\(accountType)) - \(enabled ? "Enabled" : "Disabled")")
        discoveredAccounts.append((account: account, name: name, isEnabled: enabled))
    }
    
    print("\n✅ Found \(discoveredAccounts.count) account(s)")
    
    guard !discoveredAccounts.isEmpty else {
        print("❌ No accounts found")
        writeOutput(outputPath, success: false, error: "No accounts found", outputJSON: outputJSON)
        return
    }
    
    // Process each enabled account
    var totalMoved = 0
    var totalProcessed = 0
    var folderStats: [String: Int] = [:]
    
    for (account, accountName, isEnabled) in discoveredAccounts {
        guard isEnabled else {
            print("\n⏭️ Skipping disabled account: \(accountName)")
            continue
        }
        
        print("\n" + String(repeating: "═", count: 60))
        print("📁 Processing Account: \(accountName)")
        print(String(repeating: "═", count: 60))
        
        // Discover all mailboxes for this account
        guard let mailboxes = account.mailboxes?() else {
            print("❌ Could not access mailboxes for \(accountName)")
            continue
        }
        
        print("\n📂 Discovering Mailboxes...")
        
        var mailboxDict: [String: MailMailbox] = [:]
        var inboxMailbox: MailMailbox? = nil
        
        for i in 0..<mailboxes.count {
            if let mailbox = mailboxes.object(at: i) as? MailMailbox,
               let name = mailbox.name {
                mailboxDict[name] = mailbox
                if name.lowercased() == "inbox" {
                    inboxMailbox = mailbox
                }
            }
        }
        
        print("   ✅ Found \(mailboxDict.count) mailbox(es)")
        
        // List all folders sorted
        let sortedFolders = mailboxDict.keys.sorted()
        print("\n   📁 Available Folders:")
        for name in sortedFolders {
            let unread = mailboxDict[name]?.unreadCount ?? 0
            print("      • \(name)\(unread > 0 ? " (\(unread) unread)" : "")")
        }
        
        // Find source mailbox (prefer Inbox)
        guard let sourceMailbox = inboxMailbox else {
            print("❌ No Inbox found for \(accountName)")
            continue
        }
        
        guard let messages = sourceMailbox.messages?() else {
            print("❌ Could not access Inbox messages")
            continue
        }
        
        let totalMessages = messages.count
        print("\n📬 Inbox has \(totalMessages) message(s)")
        
        if totalMessages == 0 {
            print("   ✨ Nothing to organize!")
            continue
        }
        
        // Get list of target folders (all except system folders)
        let systemFolders: Set<String> = ["inbox", "sent", "drafts", "trash", "junk", "spam", "archive", "deleted"]
        let targetFolders = mailboxDict.keys.filter { !systemFolders.contains($0.lowercased()) }
        
        print("\n🎯 Organizing into \(targetFolders.count) folder(s)...")
        
        // Process messages
        let processCount = limit != nil ? min(limit!, totalMessages) : totalMessages
        var movedThisAccount = 0
        
        for i in 0..<processCount {
            guard let message = messages.object(at: i) as? MailMessage,
                  let subject = message.subject,
                  let sender = message.sender else { continue }
            
            // Find best matching folder
            if let targetFolder = findBestFolder(
                subject: subject,
                sender: sender,
                availableFolders: Array(targetFolders)
            ) {
                if let targetMailbox = mailboxDict[targetFolder] {
                    let shortSubject = subject.count > 40 ? String(subject.prefix(40)) + "..." : subject
                    
                    if dryRun {
                        print("   [DRY RUN] Would move to [\(targetFolder)]: \(shortSubject)")
                    } else {
                        print("   ➡️ [\(targetFolder)] \(shortSubject)")
                        message.moveTo?(targetMailbox as? SBObject)
                    }
                    movedThisAccount += 1
                    folderStats[targetFolder, default: 0] += 1
                }
            }
            
            Thread.sleep(forTimeInterval: 0.02)
        }
        
        totalMoved += movedThisAccount
        totalProcessed += processCount
        
        print("\n   📊 Account Summary: \(movedThisAccount) emails \(dryRun ? "would be " : "")moved")
    }
    
    // Final summary
    print("\n" + String(repeating: "═", count: 60))
    print("📊 FINAL SUMMARY")
    print(String(repeating: "═", count: 60))
    print("   Accounts processed: \(discoveredAccounts.count)")
    print("   Total emails processed: \(totalProcessed)")
    print("   Total emails \(dryRun ? "would be " : "")moved: \(totalMoved)")
    
    if !folderStats.isEmpty {
        print("\n📁 Emails per Folder:")
        let sorted = folderStats.sorted { $0.value > $1.value }
        for (folder, count) in sorted {
            print("   \(folder): \(count)")
        }
    }
    
    if dryRun {
        print("\n⚠️ Dry run - no emails were actually moved")
    }
    
    print("\n✨ Done!")
    
    // Write JSON output if requested
    if outputJSON {
        writeFullOutput(outputPath, success: true, accountsProcessed: discoveredAccounts.count, totalProcessed: totalProcessed, totalMoved: totalMoved, folderStats: folderStats, dryRun: dryRun)
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

func writeFullOutput(_ path: String, success: Bool, accountsProcessed: Int, totalProcessed: Int, totalMoved: Int, folderStats: [String: Int], dryRun: Bool) {
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "dryRun": dryRun,
        "accountsProcessed": accountsProcessed,
        "totalProcessed": totalProcessed,
        "totalMoved": totalMoved,
        "folderStats": folderStats
    ]
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}