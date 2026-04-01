import Foundation

/// Manages which accessibility actions are enabled/disabled.
/// All actions default to ENABLED. Users can disable per-item.
@MainActor
public final class AccessibilityPermissions {
    public static let shared = AccessibilityPermissions()

    private let enabledKey = "accessibilityEnabledActions"
    private var enabledSet: Set<String>

    private init() {
        if let saved = UserDefaults.standard.array(forKey: enabledKey) as? [String] {
            var set = Set(saved)
            // Auto-enable new IDs that weren't in the saved set
            let all = AccessibilityEnabledIDs.allAxIds
            let newIds = all.subtracting(set)
            set.formUnion(newIds)
            enabledSet = set
        } else {
            enabledSet = AccessibilityEnabledIDs.allAxIds
        }
    }

    /// Check if an action ID is restricted (disabled by user)
    public func isRestricted(_ id: String) -> Bool {
        guard AccessibilityEnabledIDs.allAxIds.contains(id) else { return false }
        return !enabledSet.contains(id)
    }

    /// Check if an action ID is enabled
    public func isEnabled(_ id: String) -> Bool {
        enabledSet.contains(id)
    }

    /// Toggle an action on/off
    public func toggle(_ id: String) {
        if enabledSet.contains(id) {
            enabledSet.remove(id)
        } else {
            enabledSet.insert(id)
        }
        save()
    }

    /// Enable all actions
    public func enableAll() {
        enabledSet = AccessibilityEnabledIDs.allAxIds
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(enabledSet), forKey: enabledKey)
    }
}
