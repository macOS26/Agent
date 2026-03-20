import Foundation
import Cocoa

struct InteractionRecord: Codable {
    let timestamp: Double
    let action: String
    let appBundleId: String
    let appName: String
    let windowTitle: String?
    let elementRole: String?
    let elementTitle: String?
    let elementValue: String?
    let elementPosition: [String: Double]?
    let text: String?
    let keyCode: Int?
    let modifiers: [String]?
}

struct RecordingSession: Codable {
    var startTime: Double
    var endTime: Double?
    var interactions: [InteractionRecord]
    let sessionName: String
}

class Recorder: @unchecked Sendable {
    var session: RecordingSession
    var lastEventTime: Double = 0
    let minInterval: Double = 0.3
    var shouldStop: Bool = false
    var stopReason: String = ""
    let lock = NSLock()
    
    init(sessionName: String) {
        self.session = RecordingSession(
            startTime: Date().timeIntervalSince1970,
            endTime: nil,
            interactions: [],
            sessionName: sessionName
        )
    }
    
    func getModifierFlags(_ flags: CGEventFlags) -> [String] {
        var mods: [String] = []
        if flags.contains(.maskCommand) { mods.append("command") }
        if flags.contains(.maskAlternate) { mods.append("option") }
        if flags.contains(.maskControl) { mods.append("control") }
        if flags.contains(.maskShift) { mods.append("shift") }
        return mods
    }
    
    func recordInteraction(action: String, element: AXUIElement?, position: CGPoint? = nil, text: String? = nil, keyCode: Int? = nil, modifiers: [String]? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date().timeIntervalSince1970
        
        // Throttle events
        guard now - lastEventTime > minInterval else { return }
        lastEventTime = now
        
        // Get app info
        let runningApps = NSWorkspace.shared.runningApplications
        let frontmostApp = runningApps.first { $0.isActive }
        let appBundleId = frontmostApp?.bundleIdentifier ?? "unknown"
        let appName = frontmostApp?.localizedName ?? "Unknown"
        
        // Get window title
        var windowTitle: String?
        if let app = element {
            var windowRef: AnyObject?
            AXUIElementCopyAttributeValue(app, kAXWindowAttribute as CFString, &windowRef)
            if let window = windowRef {
                var titleRef: AnyObject?
                AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
                windowTitle = (titleRef as? String)
            }
        }
        
        // Get element details
        var elementRole: String?
        var elementTitle: String?
        var elementValue: String?
        var elementPosition: [String: Double]?
        
        if let el = element {
            var roleRef: AnyObject?
            var titleRef: AnyObject?
            var valueRef: AnyObject?
            var posRef: AnyObject?
            
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(el, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valueRef)
            AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef)
            
            elementRole = roleRef as? String
            elementTitle = titleRef as? String
            elementValue = valueRef as? String
            
            // Get position from AXValue
            if let posVal = posRef, CFGetTypeID(posVal) == AXValueGetTypeID() {
                let pos = unsafeDowncast(posVal, to: AXValue.self)
                var point: CGPoint = .zero
                AXValueGetValue(pos, .cgPoint, &point)
                elementPosition = ["x": point.x, "y": point.y]
            }
        } else if let pos = position {
            elementPosition = ["x": pos.x, "y": pos.y]
        }
        
        let record = InteractionRecord(
            timestamp: now,
            action: action,
            appBundleId: appBundleId,
            appName: appName,
            windowTitle: windowTitle,
            elementRole: elementRole,
            elementTitle: elementTitle,
            elementValue: elementValue,
            elementPosition: elementPosition,
            text: text,
            keyCode: keyCode,
            modifiers: modifiers
        )
        
        session.interactions.append(record)
        
        // Print live feedback
        let parts: [String] = [
            action,
            appName,
            elementRole ?? "",
            elementTitle ?? ""
        ].filter { !$0.isEmpty }
        
        print("✅ \(parts.joined(separator: " → "))")
    }
    
    func generateSwiftCode() -> String {
        var code = """
        // Auto-generated Accessibility Automation
        // Session: \(session.sessionName)
        // Generated: \(Date())
        // Interactions: \(session.interactions.count)
        
        // To replay this recording, use the Accessibility tools:
        // - ax_find_element() to locate elements
        // - ax_click_element() to click
        // - ax_type_text() or ax_type_into_element() to type
        // - ax_press_key() for keyboard shortcuts
        
        """
        
        for (index, interaction) in session.interactions.enumerated() {
            let stepNum = index + 1
            
            switch interaction.action {
            case "click":
                if let pos = interaction.elementPosition {
                    code += """
                
                // Step \(stepNum): Click on \(interaction.elementRole ?? "element")
                // App: \(interaction.appName)
                // Bundle ID: \(interaction.appBundleId)
                // Role: \(interaction.elementRole ?? "")
                // Title: \(interaction.elementTitle ?? "")
                // Position: (\(pos["x"]!), \(pos["y"]!))
                // 
                // Swift code to replay:
                // ax_find_element(appBundleId: "\(interaction.appBundleId)", role: "\(interaction.elementRole ?? "")", title: "\(interaction.elementTitle ?? "")", timeout: 5.0)
                // ax_click_element(appBundleId: "\(interaction.appBundleId)", role: "\(interaction.elementRole ?? "")", title: "\(interaction.elementTitle ?? "")")
                
                """
                }
                
            case "keyPress":
                if let keyCode = interaction.keyCode {
                    let modStr = (interaction.modifiers ?? []).joined(separator: ", ")
                    code += """
                
                // Step \(stepNum): Press key
                // App: \(interaction.appName)
                // Key code: \(keyCode)
                // Modifiers: \(modStr.isEmpty ? "none" : modStr)
                //
                // Swift code to replay:
                // ax_press_key(keyCode: \(keyCode), modifiers: [\(modStr)])
                
                """
                }
                
            default:
                code += """
            
            // Step \(stepNum): \(interaction.action)
            
            """
            }
        }
        
        return code
    }
    
    func save() {
        session.endTime = Date().timeIntervalSince1970
        
        let jsonDir = NSString(string: "~/Documents/AgentScript/json/").expandingTildeInPath
        let recordingsDir = NSString(string: "~/Documents/AgentScript/recordings/").expandingTildeInPath
        
        try? FileManager.default.createDirectory(atPath: jsonDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: recordingsDir, withIntermediateDirectories: true)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(session) {
            let jsonPath = (jsonDir as NSString).appendingPathComponent("\(session.sessionName)_recording.json")
            try? data.write(to: URL(fileURLWithPath: jsonPath))
            print("📄 JSON saved: \(jsonPath)")
        }
        
        let swiftCode = generateSwiftCode()
        let swiftPath = (recordingsDir as NSString).appendingPathComponent("\(session.sessionName)_automation.swift")
        try? swiftCode.write(toFile: swiftPath, atomically: true, encoding: .utf8)
        print("🤖 Swift code saved: \(swiftPath)")
    }
}

@_cdecl("script_main")
public func scriptMain() -> Int32 {
    // Parse args: "sessionName" or "timeout:60" or "sessionName,timeout:60"
    let args = ProcessInfo.processInfo.environment["AGENT_SCRIPT_ARGS"] ?? ""
    var sessionName = "recording_\(Int(Date().timeIntervalSince1970))"
    var timeout: Double = 300.0 // Default 5 minutes
    
    if !args.isEmpty {
        let parts = args.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        for part in parts {
            if part.hasPrefix("timeout:") {
                timeout = Double(part.dropFirst(8)) ?? 300.0
            } else if part.hasPrefix("name:") {
                sessionName = String(part.dropFirst(5))
            } else if !part.contains(":") {
                // Legacy: just the session name
                sessionName = part
            }
        }
    }
    
    let recorder = Recorder(sessionName: sessionName)
    
    // Create stop file path
    let stopFilePath = NSString(string: "~/Documents/AgentScript/json/stop_recording").expandingTildeInPath
    
    print("🎬 Accessibility Recorder Starting...")
    print("📁 Session: \(sessionName)")
    print("⏱️  Max duration: \(Int(timeout)) seconds")
    print("")
    print("🛑 STOP METHODS:")
    print("   • Press ESCAPE key")
    print("   • Press CONTROL+C")
    print("   • Create stop file: ~/Documents/AgentScript/json/stop_recording")
    print("")
    print("🎯 Recording clicks and keystrokes...")
    print("")
    
    // Create event tap
    let eventMask: CGEventMask =
        (1 << CGEventType.leftMouseDown.rawValue) |
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue)
    
    guard let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventMask,
        callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
            guard let recorderPtr = userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let rec = Unmanaged<Recorder>.fromOpaque(recorderPtr).takeUnretainedValue()
            
            // Check for ESC key (keyCode 53) to stop
            if type == .keyDown {
                let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                if keyCode == 53 { // ESC
                    rec.lock.lock()
                    rec.shouldStop = true
                    rec.stopReason = "ESC key pressed"
                    rec.lock.unlock()
                    CFRunLoopStop(CFRunLoopGetCurrent())
                    return Unmanaged.passUnretained(event)
                }
            }
            
            // Record interactions (don't consume events)
            if type == .leftMouseDown {
                let location = event.location
                let systemWide = AXUIElementCreateSystemWide()
                
                var element: AXUIElement?
                AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &element)
                
                rec.recordInteraction(
                    action: "click",
                    element: element,
                    position: location
                )
            } else if type == .keyDown {
                let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                let modifiers = rec.getModifierFlags(event.flags)
                
                rec.recordInteraction(
                    action: "keyPress",
                    element: nil,
                    position: nil,
                    keyCode: keyCode,
                    modifiers: modifiers.isEmpty ? nil : modifiers
                )
            }
            
            return Unmanaged.passUnretained(event)
        },
        userInfo: Unmanaged.passUnretained(recorder).toOpaque()
    ) else {
        print("❌ Could not create event tap. Check Accessibility permissions.")
        print("   Go to System Settings → Privacy & Security → Accessibility")
        print("   Add 'Agent' to the allowed apps.")
        return 1
    }
    
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    
    // Timer to check for stop file
    let stopFileTimer: Timer? = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        if FileManager.default.fileExists(atPath: stopFilePath) {
            recorder.lock.lock()
            recorder.shouldStop = true
            recorder.stopReason = "Stop file detected"
            recorder.lock.unlock()
            try? FileManager.default.removeItem(atPath: stopFilePath)
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }
    if let timer = stopFileTimer {
        RunLoop.current.add(timer, forMode: .common)
    }
    
    // Stop after timeout using nonMainActor-isolated context
    let timeoutRecorder = recorder
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
        timeoutRecorder.lock.lock()
        if !timeoutRecorder.shouldStop {
            timeoutRecorder.shouldStop = true
            timeoutRecorder.stopReason = "Timeout reached"
        }
        timeoutRecorder.lock.unlock()
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    
    print("🔴 Recording... (Press ESC to stop)")
    print("")
    
    CFRunLoopRun()
    
    // Cleanup
    stopFileTimer?.invalidate()
    CGEvent.tapEnable(tap: tap, enable: false)
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    
    print("")
    print("⏹️  Recording stopped: \(recorder.stopReason)")
    print("💾 Saving session...")
    
    recorder.save()
    
    // Print summary
    print("")
    print("📊 Session Summary:")
    let duration = Date().timeIntervalSince1970 - recorder.session.startTime
    print("   Duration: \(String(format: "%.1f", duration)) seconds")
    print("   Interactions: \(recorder.session.interactions.count)")
    
    let apps = Set(recorder.session.interactions.map { $0.appName })
    print("   Apps used: \(apps.sorted().joined(separator: ", "))")
    
    let actions = Dictionary(grouping: recorder.session.interactions, by: { $0.action })
    for (action, items) in actions.sorted(by: { $0.key < $1.key }) {
        print("   \(action): \(items.count)")
    }
    
    print("")
    print("✅ Done! Use the saved files for playback automation.")
    
    return 0
}