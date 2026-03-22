import Foundation
import ScriptingBridge
import AppKit

/// Executes top-level Apple Event queries using KVC (Key-Value Coding).
/// No bridge protocols needed — uses pure ObjC value(forKey:) dispatch.
/// All keys must be in camelCase format.
final class AppleEventService: @unchecked Sendable {
    static let shared = AppleEventService()
    
    private static let maxOutputLines = 500
    private static let defaultLimit = 50
    
    /// Execute a query against a scriptable application.
    /// Runs osascript first to trigger the Automation permission dialog if needed.
    nonisolated func execute(bundleID: String, operations: [[String: Any]]) -> String {
        let sanitizedBundleID = sanitizeBundleID(bundleID)
        guard !sanitizedBundleID.isEmpty else {
            return "Error: Invalid bundle identifier. Must be in reverse-DNS format (e.g., com.apple.Music)"
        }
        
        let appName = resolveAppName(sanitizedBundleID)
        grantPermissionViaOsascript(appName: appName, bundleID: sanitizedBundleID)
        return run(bundleID: sanitizedBundleID, operations: operations)
    }
    
    /// Validate and sanitize a bundle identifier.
    private func sanitizeBundleID(_ bundleID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // Bundle IDs: alphanumeric, dots, hyphens; at least one dot (reverse-DNS)
        let validPattern = "^[a-zA-Z0-9.-]+$"
        guard trimmed.range(of: validPattern, options: .regularExpression) != nil else { return "" }
        guard trimmed.contains(".") else { return "" }
        guard trimmed.count <= 255 else { return "" }
        
        return trimmed
    }
    
    /// Apps already granted permission this session
    private var grantedApps: Set<String> = []
    
    /// Automation permission timeout
    private let automationFinishTimeout: DispatchTime = .now() + .seconds(10)
    
    /// Trigger macOS Automation permission dialog via osascript.
    private func grantPermissionViaOsascript(appName: String, bundleID: String) {
        if grantedApps.contains(bundleID) { return }
        grantedApps.insert(bundleID)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let safeAppName = appName.isEmpty ? bundleID : appName
        process.arguments = ["-e", "tell application \"\(safeAppName)\" to get every window"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            let deadline = automationFinishTimeout
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
        
        // Pre-load SDEF for hints
        _ = SDEFService.shared.loadByBundleID(bundleID)
        
        // Show available top-level properties as hints
        let topKeys = SDEFService.shared.aeKeys(for: bundleID, className: "application")
        let topHints = topKeys.properties + topKeys.elements
        var output: [String] = []
        if !topHints.isEmpty {
            output.append("Available: \(topHints.joined(separator: ", "))")
        }
        
        // Cursor stays at app level — we only do top-level KVC
        var cursor: Any = app
        
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
                
                // Key must be camelCase
                let camelKey = ensureCamelCase(key)
                
                if let result = getValue(from: cursor, key: camelKey) {
                    if isScalar(result) {
                        output.append("\(camelKey) = \(formatValue(result))")
                    } else if let array = result as? SBElementArray {
                        output.append("\(camelKey) = \(array.count) items")
                    } else {
                        output.append("\(camelKey) = \(formatValue(result))")
                    }
                } else {
                    // Key not found — suggest valid keys
                    let keys = SDEFService.shared.aeKeys(for: bundleID, className: "application")
                    let allKeys = keys.properties + keys.elements
                    let hint = allKeys.isEmpty ? "" : " Valid keys: \(allKeys.joined(separator: ", "))"
                    output.append("\(camelKey) = nil (key not found).\(hint)")
                    return output.joined(separator: "\n")
                }
                
            case "iterate":
                guard let properties = op["properties"] as? [String] else {
                    output.append("Error at step \(i): 'iterate' requires 'properties' array")
                    return output.joined(separator: "\n")
                }
                let limit = op["limit"] as? Int ?? Self.defaultLimit
                
                // Iterate over app's element arrays (tracks, playlists, etc.)
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
                        let line = readProperties(from: item, properties: properties, bundleID: bundleID)
                        output.append("[\(idx)] \(line)")
                    }
                    if count > cap {
                        output.append("(\(count) total, showing first \(cap))")
                    }
                } else {
                    // Single object — read properties directly
                    let line = readProperties(from: cursor, properties: properties, bundleID: bundleID)
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
                // Ensure camelCase
                let camelMethod = method.contains(" ") ? toCamelCase(method) : method
                let result = callMethod(on: cursor, method: camelMethod, arg: op["arg"] as? String)
                if let r = result {
                    if isScalar(r) {
                        output.append("\(camelMethod)() = \(formatValue(r))")
                    }
                } else {
                    let nsObj = cursor as? NSObject
                    let sel = Selector(camelMethod)
                    if nsObj?.responds(to: sel) == true {
                        output.append("\(camelMethod)() executed (no return value)")
                    } else {
                        output.append("Error: '\(camelMethod)' not found")
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
    
    /// Get a property value via pure KVC dispatch.
    /// No bridge protocols needed — works on any NSObject.
    private func getValue(from object: Any, key: String) Any? {
        guard let nsObj = object as? NSObject else { return nil }
        
        // Try selector first (for methods like currentTrack, tracks())
        let sel = Selector(key)
        if nsObj.responds(to: sel) {
            if let result = ObjCSafePerform(nsObj, sel) {
                return result
            }
        }
        
        // KVC fallback — handles primitives and properties
        var result: Any?
        let success = ObjCTry {
            result = nsObj.value(forKey: key)
        }
        return success ? result : nil
    }
    
    /// Ensure key is in camelCase format.
    private func ensureCamelCase(_ key: String) -> String {
        // Already camelCase if it has lowercase letter followed by uppercase
        if key.range(of: "[a-z][A-Z]", options: .regularExpression) != nil {
            return key
        }
        // Convert "next_track" or "next track" to "nextTrack"
        return toCamelCase(key)
    }
    
    /// Convert "next track" or "next_track" to "nextTrack"
    private func toCamelCase(_ input: String) -> String {
        let words = input.split(whereSeparator: { $0 == " " || $0 == "_" })
        guard let first = words.first else { return input }
        return String(first).lowercased() + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
    
    private func callMethod(on object: Any, method: String, arg: String?) -> Any? {
        guard let nsObj = object as? NSObject else { return nil }
        
        if let arg = arg {
            let sel = Selector("\(method):")
            guard nsObj.responds(to: sel) else { return nil }
            var result: Any?
            let success = ObjCTry {
                result = nsObj.perform(sel, with: arg)?.takeUnretainedValue()
            }
            return success ? result : nil
        } else {
            let sel = Selector(method)
            guard nsObj.responds(to: sel) else { return nil }
            var result: Any?
            let success = ObjCTry {
                result = nsObj.perform(sel)?.takeUnretainedValue()
            }
            return success ? result : nil
        }
    }
    
    private func readProperties(from object: Any, properties: [String], bundleID: String) -> String {
        var parts: [String] = []
        for prop in properties {
            let camelProp = ensureCamelCase(prop)
            let val = getValue(from: object, key: camelProp)
            parts.append("\(camelProp): \(formatValue(val))")
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