import Foundation
import CalendarBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    todayEvents()
    return 0
}

func todayEvents() {
    // Parse arguments from AGENT_SCRIPT_ARGS or JSON input
    let argsString = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    let home = NSHomeDirectory()
    let inputPath = "\(home)/Documents/AgentScript/json/TodayEvents_input.json"
    let outputPath = "\(home)/Documents/AgentScript/json/TodayEvents_output.json"
    
    // Default options
    var showLocation = true
    var daysAhead = 0  // 0 = today only
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
                case "location": showLocation = value.lowercased() == "true"
                case "days": daysAhead = Int(value) ?? 0
                case "json": outputJSON = value.lowercased() == "true"
                default: break
                }
            }
        }
    }
    
    // Try JSON input file
    if let data = FileManager.default.contents(atPath: inputPath),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        if let l = json["location"] as? Bool { showLocation = l }
        if let d = json["days"] as? Int { daysAhead = d }
        if let j = json["json"] as? Bool { outputJSON = j }
    }
    
    guard let cal: CalendarApplication = SBApplication(bundleIdentifier: "com.apple.iCal") else {
        print("Could not connect to Calendar.app")
        writeTodayEventsOutput(outputPath, success: false, error: "Could not connect to Calendar.app", outputJSON: outputJSON)
        return
    }

    let now = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: now)
    guard let endOfDay = calendar.date(byAdding: .day, value: daysAhead + 1, to: startOfDay) else {
        print("Could not calculate end of day")
        writeTodayEventsOutput(outputPath, success: false, error: "Could not calculate end of day", outputJSON: outputJSON)
        return
    }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    print("Events for \(formatter.string(from: now))" + (daysAhead > 0 ? " (+\(daysAhead) days)" : ""))
    print("========================")

    let timeFormatter = DateFormatter()
    timeFormatter.dateStyle = .none
    timeFormatter.timeStyle = .short

    guard let calendars = cal.calendars?() else {
        print("No calendars found")
        writeTodayEventsOutput(outputPath, success: false, error: "No calendars found", outputJSON: outputJSON)
        return
    }

    let predicate = NSPredicate(format: "startDate < %@ AND endDate > %@", endOfDay as NSDate, startOfDay as NSDate)

    var eventCount = 0
    var allEvents: [[String: Any]] = []

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
            let loc = showLocation && !location.isEmpty ? " (\(location))" : ""

            print("  [\(calName)] \(time): \(summary)\(loc)")
            eventCount += 1
            
            allEvents.append([
                "summary": summary,
                "calendar": calName,
                "startTime": start ?? Date(),
                "endTime": end ?? Date(),
                "allDay": allDay,
                "location": location.isEmpty ? nil : location
            ] as [String : Any])
        }
    }

    if eventCount == 0 {
        print("  No events today")
    }
    print("\nTotal: \(eventCount) events")
    
    // Write JSON output if requested
    if outputJSON {
        writeTodayEventsOutput(outputPath, success: true, events: allEvents, count: eventCount, outputJSON: true)
    }
}

func writeTodayEventsOutput(_ path: String, success: Bool, error: String? = nil, events: [[String: Any]]? = nil, count: Int? = nil, outputJSON: Bool) {
    guard outputJSON else { return }
    
    var result: [String: Any] = [
        "success": success,
        "timestamp": ISO8601DateFormatter().string(from: Date())
    ]
    
    if !success, let error = error {
        result["error"] = error
    }
    
    if success {
        if let events = events { result["events"] = events }
        if let count = count { result["count"] = count }
    }
    
    try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if let out = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
        try? out.write(to: URL(fileURLWithPath: path))
        print("\n📄 JSON saved to: \(path)")
    }
}