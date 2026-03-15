import Foundation
import SystemEventsBridge

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    runningApps()
    return 0
}

func runningApps() {
    guard let sysEvents: SystemEventsApplication = SBApplication(bundleIdentifier: "com.apple.systemevents") else {
        print("Could not connect to System Events")
        return
    }

    print("Running Applications")
    print("====================")

    guard let procs = sysEvents.processes?() else {
        print("Could not list processes")
        return
    }

    var apps: [(String, Bool)] = []

    for i in 0..<procs.count {
        guard let proc = procs.object(at: i) as? SystemEventsProcess,
              let name = proc.name else { continue }

        let frontmost = proc.frontmost ?? false
        apps.append((name, frontmost))
    }

    apps.sort { $0.0.lowercased() < $1.0.lowercased() }

    for (name, frontmost) in apps {
        let marker = frontmost ? " *" : ""
        print("  \(name)\(marker)")
    }

    print("\nTotal: \(apps.count) processes")
    print("(* = frontmost)")
}
