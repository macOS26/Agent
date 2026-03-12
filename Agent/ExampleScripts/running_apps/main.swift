import Foundation
import SystemEventsBridge

// Running Apps — lists running applications via System Events

guard let sysEvents: SystemEventsApplication = SBApplication(bundleIdentifier: "com.apple.systemevents") else {
    print("Could not connect to System Events")
    exit(1)
}

print("Running Applications")
print("====================")

guard let procs = sysEvents.processes?() else {
    print("Could not list processes")
    exit(0)
}

var apps: [(String, Bool)] = []

for i in 0..<procs.count {
    guard let proc = procs.object(at: i) as? SystemEventsProcess,
          let name = proc.name else { continue }

    let frontmost = proc.frontmost ?? false
    apps.append((name, frontmost))
}

// Sort alphabetically
apps.sort { $0.0.lowercased() < $1.0.lowercased() }

for (name, frontmost) in apps {
    let marker = frontmost ? " *" : ""
    print("  \(name)\(marker)")
}

print("\nTotal: \(apps.count) processes")
print("(* = frontmost)")
