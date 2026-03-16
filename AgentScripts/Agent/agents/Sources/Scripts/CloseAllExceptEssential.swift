import Foundation
import AppKit

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    closeAllExceptEssential()
    return 0
}

func closeAllExceptEssential() {
    let essentialApps = ["Xcode", "Terminal", "Agent"]
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications

    for app in runningApps {
        guard let appName = app.localizedName else { continue }
        if !essentialApps.contains(appName) && app.activationPolicy == .regular {
            app.terminate()
        }
    }
}
