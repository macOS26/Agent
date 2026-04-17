import AgentAudit
import Foundation

/// / Executes AppleScript code in-process via NSAppleScript. / Runs in the Agent app process, inheriting ALL TCC grants
/// (Automation, Accessibility, ScreenRecording). / Use SDEFService to look up correct terminology before building scripts.
final class NSAppleScriptService: @unchecked Sendable {
    static let shared = NSAppleScriptService()

    /// AppleScript verbs considered destructive. Blocked by default unless
    /// the caller explicitly passes `allowWrites: true`.
    private static let destructiveVerbs: [String] = [
        "delete", "remove", "close", "move", "quit",
        "shut down", "restart", "log out", "empty trash",
        "do shell script",
    ]

    /// Returns a human-readable reason when `source` contains a destructive
    /// verb and `allowWrites` is false, nil otherwise.
    static func writeProtectionCheck(source: String, allowWrites: Bool) -> String? {
        guard !allowWrites else { return nil }
        let lower = source.lowercased()
        for verb in destructiveVerbs {
            if lower.contains(verb) {
                return "AppleScript contains destructive verb \"\(verb)\". "
                    + "Set allow_writes: true to permit this operation, "
                    + "or rewrite the script to avoid \(verb)."
            }
        }
        return nil
    }

    /// Execute AppleScript source code and return the result.
    /// Runs synchronously on the calling thread — call from offMain.
    /// When `allowWrites` is false (the default), scripts containing
    /// destructive verbs are refused before execution.
    func execute(source: String, allowWrites: Bool = false) -> (success: Bool, output: String) {
        if let blocked = Self.writeProtectionCheck(source: source, allowWrites: allowWrites) {
            AuditLog.log(.appleScript, "BLOCKED (write-protection): \(source.prefix(100))")
            return (false, blocked)
        }

        AuditLog.log(.appleScript, "execute: \(source.prefix(100))")
        var errorInfo: NSDictionary?
        let script = NSAppleScript(source: source)

        guard let result = script?.executeAndReturnError(&errorInfo) else {
            let error = formatError(errorInfo)
            return (false, "AppleScript error: \(error)")
        }

        let output = formatResult(result)
        return (true, output)
    }

    /// Build and execute an AppleScript that targets a specific app by bundle ID.
    /// Automatically wraps the body in `tell application id "bundle.id"`.
    func executeForApp(bundleID: String, body: String, allowWrites: Bool = false) -> (success: Bool, output: String) {
        let source = """
        tell application id "\(bundleID)"
            \(body)
        end tell
        """
        return execute(source: source, allowWrites: allowWrites)
    }

    /// Get SDEF summary for an app to help build correct AppleScript.
    func sdefSummary(for bundleID: String) -> String {
        return SDEFService.shared.summary(for: bundleID)
    }

    // MARK: - Formatting

    private func formatError(_ info: NSDictionary?) -> String {
        guard let info = info else { return "Unknown error" }
        var parts: [String] = []
        if let message = info[NSAppleScript.errorMessage] as? String {
            parts.append(message)
        }
        if let number = info[NSAppleScript.errorNumber] as? Int {
            parts.append("(\(number))")
        }
        if let brief = info[NSAppleScript.errorBriefMessage] as? String, !parts.contains(where: { $0.contains(brief) }) {
            parts.append(brief)
        }
        return parts.isEmpty ? "Unknown error" : parts.joined(separator: " ")
    }

    private func formatResult(_ descriptor: NSAppleEventDescriptor) -> String {
        // Try string first
        if let str = descriptor.stringValue {
            return str
        }

        // List
        let count = descriptor.numberOfItems
        if count > 0 {
            var items: [String] = []
            for i in 1...count {
                let item = descriptor.atIndex(i)
                if let str = item?.stringValue {
                    items.append(str)
                } else if let num = item?.int32Value as? Int32 {
                    items.append("\(num)")
                } else {
                    items.append(item?.stringValue ?? "(unknown)")
                }
            }
            return items.joined(separator: "\n")
        }

        // Number types
        switch descriptor.descriptorType {
        case typeTrue:
            return "true"
        case typeFalse:
            return "false"
        case typeSInt32, typeSInt16:
            return "\(descriptor.int32Value)"
        case typeIEEE64BitFloatingPoint, typeIEEE32BitFloatingPoint:
            return "\(descriptor.doubleValue)"
        default:
            return descriptor.stringValue ?? "(no result)"
        }
    }
}
