import Foundation
import RemindersBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listReminders()
    return 0
}

func listReminders() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/ListReminders_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/ListReminders_output.json"
    
    // Default options
    var showCompleted = false
    var limit = 10
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
                case "completed": showCompleted = value.lowercased() == "true"
                case "limit": limit = Int(value) ?? 10
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let c = json["completed"] as? Bool { showCompleted = c }
        if let l = json["limit"] as? Int { limit = l }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let app: RemindersApplication = SBApplication(bundleIdentifier: "com.apple.reminders") else {
        print("Could not connect to Reminders.app")
        writeListRemindersOutput(outputPath, success: false, error: "Could not connect to Reminders.app", outputJSON: outputJSON)
        return
    }

    print("Reminders")
    print("=========")

    guard let lists = app.lists?(), lists.count > 0 else {
        print("No reminder lists found.")
        writeListRemindersOutput(outputPath, success: false, error: "No reminder lists found", outputJSON: outputJSON)
        return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short

    var totalIncomplete = 0
    var allReminders: [[String: Any]] = []

    for i in 0..<lists.count {
        guard let list = lists.object(at: i) as? RemindersList,
              let listName = list.name,
              let reminders = list.reminders?() else { continue }

        var incomplete: [[String: Any]] = []

        for j in 0..<reminders.count {
            guard let reminder = reminders.object(at: j) as? RemindersReminder,
                  let name = reminder.name else { continue }

            let done = reminder.completed ?? false
            
            // Skip completed if not showing them
            if done && !showCompleted { continue }
            
            let dueString: String
            if let nsDate = (reminder as AnyObject).value(forKey: "dueDate") as? NSDate {
                dueString = dateFormatter.string(from: nsDate as Date)
            } else {
                dueString = ""
            }
            
            incomplete.append([
                "name": name,
                "completed": done,
                "dueDate": dueString
            ])
        }

        guard !incomplete.isEmpty else { continue }
        
        if !showCompleted {
            totalIncomplete += incomplete.count
        }

        print("\n\(listName) (\(incomplete.count))")
        for (index, item) in incomplete.prefix(limit).enumerated() {
            let name = item["name"] as? String ?? ""
            let due = item["dueDate"] as? String ?? ""
            let done = item["completed"] as? Bool ?? false
            let check = done ? "✓" : "-"
            print("  [\(check)] \(name) \(due)")
        }
        if incomplete.count > limit {
            print("  ... and \(incomplete.count - limit) more")
        }
        
        allReminders.append([
            "list": listName,
            "reminders": incomplete
        ])
    }

    if showCompleted {
        print("\nTotal: \(allReminders.count) lists")
    } else {
        print("\nTotal incomplete: \(totalIncomplete)")
    }
    
    // Write JSON output if requested
    if outputJSON {
        writeListRemindersOutput(outputPath, success: true, lists: allReminders, totalIncomplete: totalIncomplete, outputJSON: true)
    }
}

func writeListRemindersOutput(_ path: String, success: Bool, error: String? = nil, lists: [[String: Any]]? = nil, totalIncomplete: Int? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        result["error"] = error
    }
    
    if success {
        if let lists = lists { result["lists"] = lists }
        if let totalIncomplete = totalIncomplete { result["totalIncomplete"] = totalIncomplete }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}