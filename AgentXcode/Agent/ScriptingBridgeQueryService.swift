import Foundation
import ScriptingBridge
import AppKit

/// Executes dynamic ScriptingBridge queries using ObjC runtime dispatch.
/// No compilation needed — walks the object graph via value(forKey:) and perform(_:with:).
final class ScriptingBridgeQueryService: @unchecked Sendable {
    static let shared = ScriptingBridgeQueryService()

    private static let maxOutputLines = 500
    private static let defaultLimit = 50

    /// Destructive selectors blocked unless allow_writes is true
    private static let writeSelectors: Set<String> = [
        "delete", "close", "remove", "quit", "move", "moveTo",
        "duplicate", "save", "set", "sendMessage"
    ]

    /// Execute a query against a scriptable application.
    nonisolated func execute(bundleID: String, operations: [[String: Any]], allowWrites: Bool = false) -> String {
        guard !bundleID.isEmpty else { return "Error: bundle_id is required" }
        guard !operations.isEmpty else { return "Error: operations array is empty" }

        guard let app = SBApplication(bundleIdentifier: bundleID) else {
            return "Error: Could not connect to app '\(bundleID)'. Is it installed?"
        }

        var cursor: Any = app
        var output: [String] = []

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
                let result = getValue(from: cursor, key: key)
                if result == nil {
                    output.append("\(key) = nil")
                    return output.joined(separator: "\n")
                }
                if isScalar(result) {
                    output.append("\(key) = \(formatValue(result))")
                }
                cursor = result!

            case "iterate":
                guard let properties = op["properties"] as? [String] else {
                    output.append("Error at step \(i): 'iterate' requires 'properties' array")
                    return output.joined(separator: "\n")
                }
                let limit = op["limit"] as? Int ?? Self.defaultLimit

                if let array = cursor as? SBElementArray {
                    let count = array.count
                    if count == 0 {
                        output.append("(0 items — the array is empty. If this is unexpected, the app may need Automation permission. Try: osascript -e 'tell application \"AppName\" to get name')")
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
                if !allowWrites && Self.writeSelectors.contains(method) {
                    output.append("Error at step \(i): '\(method)' is a write operation. Set allow_writes=true to permit.")
                    return output.joined(separator: "\n")
                }
                let result = callMethod(on: cursor, method: method, arg: op["arg"] as? String)
                if let r = result {
                    if isScalar(r) {
                        output.append("\(method)() = \(formatValue(r))")
                    }
                    cursor = r
                } else {
                    output.append("\(method)() called")
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
            return "(no output — the query returned no data. Possible causes: 1) The app needs Automation permission — run: osascript -e 'tell application \"AppName\" to get name' to trigger the consent dialog. 2) The property key may be wrong — check the app's scripting dictionary.)"
        }
        return output.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func getValue(from object: Any, key: String) -> Any? {
        // Try value(forKey:) on NSObject
        guard let nsObj = object as? NSObject else { return nil }
        // For SBElementArray element names, try calling it as a method first
        let sel = Selector(key)
        if nsObj.responds(to: sel) {
            return nsObj.perform(sel)?.takeUnretainedValue()
        }
        // Fallback to KVC
        return (nsObj as AnyObject).value(forKey: key)
    }

    private func callMethod(on object: Any, method: String, arg: String?) -> Any? {
        guard let nsObj = object as? NSObject else { return nil }
        if let arg = arg {
            let sel = Selector("\(method):")
            if nsObj.responds(to: sel) {
                return nsObj.perform(sel, with: arg)?.takeUnretainedValue()
            }
        } else {
            let sel = Selector(method)
            if nsObj.responds(to: sel) {
                return nsObj.perform(sel)?.takeUnretainedValue()
            }
        }
        return nil
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
