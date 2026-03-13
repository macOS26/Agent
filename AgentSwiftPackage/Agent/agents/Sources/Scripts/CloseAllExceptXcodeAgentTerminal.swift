import Foundation
import AppKit

@MainActor
func quitAllExceptExcluded() {
    // List of apps to exclude from quitting
    let excludedApps = ["Xcode", "Agent", "Terminal"]

    // Get list of all running applications
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    // Filter out excluded apps and system processes
    let appsToQuit = runningApps.filter { app in
        guard let appName = app.localizedName else { return false }
        // Skip excluded apps and system processes
        if excludedApps.contains(appName) || appName.hasPrefix("com.apple.") {
            return false
        }
        // Only quit user-facing apps
        return app.activationPolicy == .regular
    }

    // Quit each app
    for app in appsToQuit {
        guard let appName = app.localizedName else { continue }
        print("Quitting: \(appName)")
        app.terminate()
    }

    print("Done. Only excluded apps remain running.")
}

// Entry point
autoreleasepool {
    quitAllExceptExcluded()
}