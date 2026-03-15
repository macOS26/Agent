import Foundation
import RemindersBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    listReminders()
    return 0
}

func listReminders() {
    guard let app: RemindersApplication = SBApplication(bundleIdentifier: "com.apple.reminders") else {
        print("Could not connect to Reminders.app")
        return
    }

    print("Reminders")
    print("=========")

    guard let lists = app.lists?(), lists.count > 0 else {
        print("No reminder lists found.")
        return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .short
    dateFormatter.timeStyle = .short

    var totalIncomplete = 0

    for i in 0..<lists.count {
        guard let list = lists.object(at: i) as? RemindersList,
              let listName = list.name,
              let reminders = list.reminders?() else { continue }

        var incomplete: [(String, String)] = []

        for j in 0..<reminders.count {
            guard let reminder = reminders.object(at: j) as? RemindersReminder,
                  let name = reminder.name else { continue }

            let done = reminder.completed ?? false
            if !done {
                let dueString: String
                if let nsDate = (reminder as AnyObject).value(forKey: "dueDate") as? NSDate {
                    dueString = "due \(dateFormatter.string(from: nsDate as Date))"
                } else {
                    dueString = ""
                }
                incomplete.append((name, dueString))
            }
        }

        guard !incomplete.isEmpty else { continue }
        totalIncomplete += incomplete.count

        print("\n\(listName) (\(incomplete.count))")
        for (name, due) in incomplete.prefix(10) {
            print("  - \(name) \(due)")
        }
        if incomplete.count > 10 {
            print("  ... and \(incomplete.count - 10) more")
        }
    }

    print("\nTotal incomplete: \(totalIncomplete)")
}
