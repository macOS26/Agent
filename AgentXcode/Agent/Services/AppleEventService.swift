import Foundation
import ScriptingBridge
import AppKit
import AppleEventBridges
import XcodeScriptingBridge

/// Executes dynamic Apple Event queries using ObjC runtime dispatch.
/// No compilation needed — walks the object graph via value(forKey:) and NSInvocation.
final class AppleEventService: @unchecked Sendable {
    static let shared = AppleEventService()

    private static let maxOutputLines = 500
    private static let defaultLimit = 50


    /// Execute a query against a scriptable application.
    /// Runs osascript first to trigger the Automation permission dialog if needed,
    /// then runs the ScriptingBridge query.
    nonisolated func execute(bundleID: String, operations: [[String: Any]]) -> String {
        // SECURITY: Validate bundle ID to prevent injection attacks
        let sanitizedBundleID = sanitizeBundleID(bundleID)
        guard !sanitizedBundleID.isEmpty else {
            return "Error: Invalid bundle identifier. Must be in reverse-DNS format (e.g., com.apple.Music)"
        }

        let appName = resolveAppName(sanitizedBundleID)
        // Run a trivial osascript to trigger the macOS Automation permission dialog.
        // This is what actually makes the "Agent wants to control X" prompt appear.
        grantPermissionViaOsascript(appName: appName, bundleID: sanitizedBundleID)
        return run(bundleID: sanitizedBundleID, operations: operations)
    }

    /// Validate and sanitize a bundle identifier.
    /// Bundle IDs must be in reverse-DNS format: alphanumeric segments separated by dots.
    /// Returns an empty string if invalid.
    private func sanitizeBundleID(_ bundleID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Bundle IDs contain alphanumeric characters, dots, and hyphens
        // They must have at least one dot (reverse-DNS format)
        let validPattern = "^[a-zA-Z0-9.-]+$"
        guard trimmed.range(of: validPattern, options: .regularExpression) != nil else { return "" }
        guard trimmed.contains(".") else { return "" }
        guard trimmed.count <= 255 else { return "" }
        
        return trimmed
    }

    /// Apps that have already been granted permission this session
    private var grantedApps: Set<String> = []

    /// Trigger the macOS Automation permission dialog by running osascript.
    /// Times out after 10 seconds to avoid blocking if the dialog is dismissed or app is unresponsive.
    private func grantPermissionViaOsascript(appName: String, bundleID: String) {
        if grantedApps.contains(bundleID) { return }
        (self as AppleEventService).grantedApps.insert(bundleID)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        // Use sanitized app name (derived from bundle ID, not arbitrary input)
        let safeAppName = appName.isEmpty ? bundleID : appName
        process.arguments = ["-e", "tell application \"\(safeAppName)\" to get every window"]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        do {
            try process.run()
            // Wait with timeout — don't block forever
            let deadline = DispatchTime.now() + 10
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                process.waitUntilExit()
                semaphore.signal()
            }
            if semaphore.wait(timeout: deadline) == .timedOut {
                process.terminate()
            }
        } catch { }
    }

    private func resolveAppName(_ bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.deletingPathExtension().lastPathComponent
        }
        return ""
    }

    private func run(bundleID: String, operations: [[String: Any]]) -> String {
        guard !bundleID.isEmpty else { return "Error: bundle_id is required" }
        guard !operations.isEmpty else { return "Error: operations array is empty" }

        guard let app = SBApplication(bundleIdentifier: bundleID) else {
            let appName = resolveAppName(bundleID)
            if appName.isEmpty {
                return "Error: Could not find app with bundle ID '\(bundleID)'. Is it installed?"
            }
            return "Error: Could not connect to '\(appName)' (\(bundleID)). Make sure the app is running."
        }

        // Pre-load SDEF so it's cached for hints during the query
        _ = SDEFService.shared.loadByBundleID(bundleID)

        // Show available top-level properties as hints
        let topKeys = SDEFService.shared.aeKeys(for: bundleID, className: "application")
        let topHints = (topKeys.properties + topKeys.elements).prefix(15)
        var output: [String] = []
        if !topHints.isEmpty {
            output.append("Available: \(topHints.joined(separator: ", "))\(topKeys.properties.count + topKeys.elements.count > 15 ? " ..." : "")")
        }

        var cursor: Any = app
        var cursorClass = "application"
        var cursorPath: [String] = []  // tracks path for NSAppleScript fallback

        for (i, op) in operations.enumerated() {
            guard let action = op["action"] as? String else {
                output.append("Error at step \(i): missing 'action'")
                break
            }

            switch action {
            case "get":
                guard let key = op["key"] as? String else {
                    output.append("Error at step \(i): 'get' requires 'key'")
                    return output.joined(separator: "\n")
                }
                if let result = getValue(from: cursor, key: key) {
                    if isScalar(result) {
                        output.append("\(key) = \(formatValue(result))")
                    }
                    // Track cursor class for SDEF hints on subsequent steps
                    if result is SBElementArray {
                        cursorClass = key
                        // Show element type hints
                        let childKeys = SDEFService.shared.aeKeys(for: bundleID, className: key)
                        let childHints = (childKeys.properties + childKeys.elements).prefix(10)
                        if !childHints.isEmpty {
                            output.append("  \(key) properties: \(childHints.joined(separator: ", "))")
                        }
                    } else if result is SBObject {
                        cursorClass = key
                        let objKeys = SDEFService.shared.aeKeys(for: bundleID, className: key)
                        let objHints = (objKeys.properties + objKeys.elements).prefix(10)
                        if !objHints.isEmpty {
                            output.append("  \(key) properties: \(objHints.joined(separator: ", "))")
                        }
                    }
                    cursorPath.append(key)
                    cursor = result
                } else if let fallbackValue = appleScriptFallback(bundleID: bundleID, key: key, cursorPath: cursorPath) {
                    // NSAppleScript fallback succeeded — return the value directly
                    output.append("\(key) = \(fallbackValue)")
                    // Can't continue chaining after fallback — AppleScript returns a string
                    return output.joined(separator: "\n")
                } else {
                    // Both KVC and NSAppleScript failed — suggest valid keys
                    let keys = SDEFService.shared.aeKeys(for: bundleID, className: cursorClass)
                    let allKeys = keys.properties + keys.elements
                    let hint = allKeys.isEmpty ? "" : " Valid keys for '\(cursorClass)': \(allKeys.joined(separator: ", "))"
                    output.append("\(key) = nil (key not found).\(hint)")
                    return output.joined(separator: "\n")
                }

            case "iterate":
                guard let properties = op["properties"] as? [String] else {
                    output.append("Error at step \(i): 'iterate' requires 'properties' array")
                    return output.joined(separator: "\n")
                }
                let limit = op["limit"] as? Int ?? Self.defaultLimit

                if let array = cursor as? SBElementArray {
                    let count = array.count
                    if count == 0 {
                        output.append("(0 items — the array is empty)")
                        return output.joined(separator: "\n")
                    }
                    let cap = min(count, limit)
                    for idx in 0..<cap {
                        guard output.count < Self.maxOutputLines else {
                            output.append("(truncated at \(Self.maxOutputLines) lines)")
                            return output.joined(separator: "\n")
                        }
                        let item = array.object(at: idx)
                        let line = readProperties(from: item, properties: properties)
                        output.append("[\(idx)] \(line)")
                    }
                    if count > cap {
                        output.append("(\(count) total, showing first \(cap))")
                    }
                } else {
                    // Single object — read properties directly
                    let line = readProperties(from: cursor, properties: properties)
                    output.append(line)
                }

            case "index":
                guard let index = op["index"] as? Int else {
                    output.append("Error at step \(i): 'index' requires 'index' integer")
                    return output.joined(separator: "\n")
                }
                guard let array = cursor as? SBElementArray else {
                    output.append("Error at step \(i): current object is not an array")
                    return output.joined(separator: "\n")
                }
                guard index >= 0 && index < array.count else {
                    output.append("Error at step \(i): index \(index) out of range (count: \(array.count))")
                    return output.joined(separator: "\n")
                }
                cursor = array.object(at: index)

            case "call":
                guard let method = op["method"] as? String else {
                    output.append("Error at step \(i): 'call' requires 'method'")
                    return output.joined(separator: "\n")
                }
                // Auto-convert "next track" → "nextTrack", "play pause" → "playPause"
                let camelMethod = method.contains(" ") ? toCamelCase(method) : method
                let result = callMethod(on: cursor, method: camelMethod, arg: op["arg"] as? String)
                if let r = result {
                    if isScalar(r) {
                        output.append("\(camelMethod)() = \(formatValue(r))")
                    }
                    cursor = r
                } else {
                    // Verify the method actually exists
                    let nsObj = cursor as? NSObject
                    let sel = Selector(camelMethod)
                    if nsObj?.responds(to: sel) == true {
                        output.append("\(camelMethod)() executed (no return value)")
                    } else {
                        // Try AppleScript fallback for commands
                        let appName = resolveAppName(bundleID)
                        let asMethod = camelCaseToAppleScript(camelMethod)
                        let script = "tell application \"\(appName)\" to \(asMethod)"
                        let asResult = NSAppleScriptService.shared.execute(source: script)
                        if asResult.success {
                            output.append("\(camelMethod)() via AppleScript: \(asResult.output)")
                        } else {
                            let keys = SDEFService.shared.aeKeys(for: bundleID, className: cursorClass)
                            let commands = keys.properties.filter { $0.contains(camelMethod.prefix(4).lowercased()) }
                            let hint = commands.isEmpty ? "" : " Try: \(commands.joined(separator: ", "))"
                            output.append("Error: '\(camelMethod)' not found on \(cursorClass).\(hint)")
                        }
                    }
                }

            case "filter":
                guard let predicateStr = op["predicate"] as? String else {
                    output.append("Error at step \(i): 'filter' requires 'predicate'")
                    return output.joined(separator: "\n")
                }
                guard let array = cursor as? SBElementArray else {
                    output.append("Error at step \(i): current object is not an array")
                    return output.joined(separator: "\n")
                }
                let predicate = NSPredicate(format: predicateStr)
                cursor = array.filtered(using: predicate)

            default:
                output.append("Error at step \(i): unknown action '\(action)'")
                return output.joined(separator: "\n")
            }
        }

        if output.isEmpty {
            return "(no output — the query returned no data)"
        }
        return output.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Get a property value from an SBObject/SBApplication via ObjC dispatch.
    /// The `import AppleEventBridges` at the top registers all bridge protocol
    /// conformances (e.g. `SBApplication: MusicApplication`), which makes
    /// ObjCSafePerform and KVC resolve selectors like `currentTrack`, `tracks()`,
    /// etc. Without the bridges, many properties would return nil.
    private func getValue(from object: Any, key: String) -> Any? {
        guard let nsObj = object as? NSObject else { return nil }
        let sel = Selector(key)
        // ObjCSafePerform checks the method signature: only invokes if the
        // return type is an object ('@'). Primitives (int, enum, etc.) return
        // nil here, so we fall through to KVC which auto-boxes them.
        if let result = ObjCSafePerform(nsObj, sel) {
            return result
        }
        // KVC fallback — handles primitives and properties that need KVC path.
        if let result = safeValueForKey(nsObj, key: key) {
            return result
        }
        return nil
    }

    /// NSAppleScript fallback for when KVC fails on object-type properties.
    /// Converts camelCase key to AppleScript terminology and queries via NSAppleScript.
    private func appleScriptFallback(bundleID: String, key: String, cursorPath: [String]) -> String? {
        let appName = resolveAppName(bundleID)
        guard !appName.isEmpty else { return nil }

        // Convert camelCase to AppleScript space-separated: "currentTrack" → "current track"
        let asKey = camelCaseToAppleScript(key)

        // Build the property path for nested access
        let source: String
        if cursorPath.isEmpty {
            source = "tell application \"\(appName)\" to get \(asKey)"
        } else {
            let path = cursorPath.map { camelCaseToAppleScript($0) }.joined(separator: " of ")
            source = "tell application \"\(appName)\" to get \(asKey) of \(path)"
        }

        let result = NSAppleScriptService.shared.execute(source: source)
        return result.success ? result.output : nil
    }

    /// Convert camelCase to AppleScript space-separated terminology.
    /// "currentTrack" → "current track", "playerState" → "player state"
    private func camelCaseToAppleScript(_ key: String) -> String {
        var result = ""
        for char in key {
            if char.isUppercase && !result.isEmpty {
                result += " "
                result += String(char).lowercased()
            } else {
                result += String(char)
            }
        }
        return result
    }

    /// Convert "next track" or "next_track" to "nextTrack"
    private func toCamelCase(_ input: String) -> String {
        let words = input.split(whereSeparator: { $0 == " " || $0 == "_" })
        guard let first = words.first else { return input }
        return String(first).lowercased() + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Safely call value(forKey:) catching ObjC exceptions
    private func safeValueForKey(_ obj: NSObject, key: String) -> Any? {
        var result: Any?
        let success = ObjCTry {
            result = obj.value(forKey: key)
        }
        return success ? result : nil
    }

    private func callMethod(on object: Any, method: String, arg: String?) -> Any? {
        guard let nsObj = object as? NSObject else { return nil }
        var result: Any?
        if let arg = arg {
            let sel = Selector("\(method):")
            guard nsObj.responds(to: sel) else { return nil }
            let success = ObjCTry {
                result = nsObj.perform(sel, with: arg)?.takeUnretainedValue()
            }
            return success ? result : nil
        } else {
            let sel = Selector(method)
            guard nsObj.responds(to: sel) else { return nil }
            let success = ObjCTry {
                result = nsObj.perform(sel)?.takeUnretainedValue()
            }
            return success ? result : nil
        }
    }

    private func readProperties(from object: Any, properties: [String]) -> String {
        var parts: [String] = []
        for prop in properties {
            let val = getValue(from: object, key: prop)
            parts.append("\(prop): \(formatValue(val))")
        }
        return parts.joined(separator: ", ")
    }

    private func isScalar(_ value: Any?) -> Bool {
        guard let v = value else { return true }
        return v is String || v is NSString ||
               v is NSNumber || v is Bool ||
               v is Int || v is Double || v is Float ||
               v is Date || v is NSDate ||
               v is URL || v is NSURL
    }

    private func formatValue(_ value: Any?) -> String {
        guard let v = value else { return "nil" }
        switch v {
        case let s as String: return "\"\(s)\""
        case let n as NSNumber: return n.stringValue
        case let d as Date:
            let fmt = ISO8601DateFormatter()
            return fmt.string(from: d)
        case let u as URL: return u.absoluteString
        case let arr as NSArray:
            let items = (0..<min(arr.count, 10)).map { "\(arr[$0])" }
            let suffix = arr.count > 10 ? ", ... (\(arr.count) total)" : ""
            return "[\(items.joined(separator: ", "))\(suffix)]"
        default:
            return String(describing: v)
        }
    }
}
