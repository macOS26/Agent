import Foundation
import CalendarBridge

@main
struct TodayEvents {
    static func main() {
        todayEvents()
    }
}

func todayEvents() {
    guard let cal: CalendarApplication = SBApplication(bundleIdentifier: "com.apple.iCal") else {
        print("Could not connect to Calendar.app")
        return
    }

    let now = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    print("Events for \(formatter.string(from: now))")
    print("========================")

    let timeFormatter = DateFormatter()
    timeFormatter.dateStyle = .none
    timeFormatter.timeStyle = .short

    guard let calendars = cal.calendars?() else {
        print("No calendars found")
        return
    }

    let predicate = NSPredicate(format: "startDate < %@ AND endDate > %@", endOfDay as NSDate, startOfDay as NSDate)

    var eventCount = 0

    for i in 0..<calendars.count {
        guard let calObj = calendars.object(at: i) as? CalendarCalendar,
              let calName = calObj.name,
              let events = calObj.events?() else { continue }

        guard let todayEvents = events.filtered(using: predicate) as? [CalendarEvent] else { continue }

        for event in todayEvents {
            guard let summary = event.summary else { continue }
            let start = event.startDate
            let end = event.endDate

            let allDay = event.alldayEvent ?? false
            let time: String
            if allDay {
                time = "All day"
            } else if let s = start, let e = end {
                time = "\(timeFormatter.string(from: s)) - \(timeFormatter.string(from: e))"
            } else {
                time = "?"
            }
            let location = event.location ?? ""
            let loc = location.isEmpty ? "" : " (\(location))"

            print("  [\(calName)] \(time): \(summary)\(loc)")
            eventCount += 1
        }
    }

    if eventCount == 0 {
        print("  No events today")
    }
    print("\nTotal: \(eventCount) events")
}
