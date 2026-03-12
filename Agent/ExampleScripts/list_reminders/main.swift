import Foundation
import ScriptingBridges

// List Reminders — shows incomplete reminders grouped by list
// Note: Requires Automation permission for Reminders in System Settings > Privacy

// Ignore SIGPIPE (sent when Reminders denies ScriptingBridge access)
signal(SIGPIPE, SIG_IGN)

guard let app: RemindersApplication = SBApplication(bundleIdentifier: "com.apple.reminders") else {
    print("Could not connect to Reminders.app")
    exit(1)
}

// Trigger a permission prompt by accessing a property
let sbApp = app as? SBApplication
sbApp?.activate()
Thread.sleep(forTimeInterval: 0.5)

print("Reminders")
print("=========")

guard let lists = app.lists?() else {
    print("No reminder lists found.")
    print("Tip: Grant Automation permission in System Settings > Privacy & Security > Automation")
    exit(0)
}

let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .short
dateFormatter.timeStyle = .short

var totalIncomplete = 0

for i in 0..<lists.count {
    guard let list = lists.object(at: i) as? RemindersList,
          let listName = list.name,
          let reminders = list.reminders?() else { continue }

    var incomplete: [(String, Date?)] = []

    for j in 0..<reminders.count {
        guard let reminder = reminders.object(at: j) as? RemindersReminder,
              let name = reminder.name else { continue }

        let done = reminder.completed ?? false
        if !done {
            incomplete.append((name, reminder.dueDate))
        }
    }

    guard !incomplete.isEmpty else { continue }
    totalIncomplete += incomplete.count

    print("\n\(listName) (\(incomplete.count))")
    for (name, dueDate) in incomplete.prefix(10) {
        let due = dueDate.map { "due \(dateFormatter.string(from: $0))" } ?? ""
        print("  - \(name) \(due)")
    }
    if incomplete.count > 10 {
        print("  ... and \(incomplete.count - 10) more")
    }
}

print("\nTotal incomplete: \(totalIncomplete)")
