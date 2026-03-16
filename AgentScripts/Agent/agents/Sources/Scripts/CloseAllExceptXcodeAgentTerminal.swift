import Foundation
import AppKit

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    quitAllExceptExcluded()
    return 0
}

func quitAllExceptExcluded() {
    let excludedApps = ["Xcode", "Agent", "Terminal"]
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    let appsToQuit = runningApps.filter { app in
        guard let appName = app.localizedName else { return false }
        if excludedApps.contains(appName) || appName.hasPrefix("com.apple.") {
            return false
        }
        return app.activationPolicy == .regular
    }

    for app in appsToQuit {
        guard let appName = app.localizedName else { continue }
        print("Quitting: \(appName)")
        app.terminate()
    }

    print("Done. Only excluded apps remain running.")
}
