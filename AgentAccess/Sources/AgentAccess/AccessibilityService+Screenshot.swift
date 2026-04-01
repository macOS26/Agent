import AgentAudit
import Foundation
import AppKit
@preconcurrency import ApplicationServices

extension AccessibilityService {
    // MARK: - Screenshot (Phase 4)

    /// Capture a screenshot of a region or window. Requires Screen Recording permission.
    /// Returns the path to the saved PNG file, or an error message.
    public func captureScreenshot(x: CGFloat? = nil, y: CGFloat? = nil, width: CGFloat? = nil, height: CGFloat? = nil, windowID: Int? = nil) -> String {
        // Check Accessibility permission (Screen Recording is same TCC category on macOS)
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility/Screen Recording permission required.")
        }
        AuditLog.log(.accessibility, "captureScreenshot(x: \(x.map(String.init) ?? "nil"), y: \(y.map(String.init) ?? "nil"), w: \(width.map(String.init) ?? "nil"), h: \(height.map(String.init) ?? "nil"), windowID: \(windowID.map(String.init) ?? "nil"))")

        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileName = "screenshot_\(UUID().uuidString).png"
        let outputPath = home.appendingPathComponent("Documents/AgentScript/screenshots/\(fileName)").path

        // Ensure output directory exists
        try? FileManager.default.createDirectory(atPath: home.appendingPathComponent("Documents/AgentScript/screenshots").path, withIntermediateDirectories: true)

        // Build screencapture command
        var args = ["-x", "-t", "png"]  // -x: no sound, -t png: format

        if let wid = windowID, wid > 0 {
            // Capture specific window by ID
            args.append("-l")
            args.append("\(wid)")
        } else if let x = x, let y = y, let w = width, let h = height {
            // Capture region
            args.append("-R")
            args.append("\(Int(x)),\(Int(y)),\(Int(w)),\(Int(h))")
        }

        args.append(outputPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                return errorJSON("screencapture failed with exit code \(process.terminationStatus)")
            }

            guard FileManager.default.fileExists(atPath: outputPath) else {
                return errorJSON("Screenshot file not created at \(outputPath)")
            }

            // Get file size for confirmation
            let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attrs[.size] as? Int64 ?? 0

            return successJSON([
                "path": outputPath,
                "size": fileSize,
                "message": "Screenshot saved to \(outputPath)"
            ])
        } catch {
            return errorJSON("Failed to capture screenshot: \(error.localizedDescription)")
        }
    }

    /// Capture a screenshot of all visible windows (requires Screen Recording permission)
    public func captureAllWindows() -> String {
        guard Self.hasAccessibilityPermission() else {
            return errorJSON("Accessibility/Screen Recording permission required.")
        }
        AuditLog.log(.accessibility, "captureAllWindows()")

        // Try to capture just the frontmost window instead of the entire screen
        let frontWindowID = Self.frontmostWindowID()

        let home = FileManager.default.homeDirectoryForCurrentUser
        let fileName = "screenshot_\(UUID().uuidString).png"
        let outputPath = home.appendingPathComponent("Documents/AgentScript/screenshots/\(fileName)").path

        try? FileManager.default.createDirectory(atPath: home.appendingPathComponent("Documents/AgentScript/screenshots").path, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if let wid = frontWindowID {
            process.arguments = ["-x", "-t", "png", "-l", "\(wid)", outputPath]
        } else {
            process.arguments = ["-x", "-t", "png", outputPath]
        }

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                return errorJSON("screencapture failed with exit code \(process.terminationStatus)")
            }

            guard FileManager.default.fileExists(atPath: outputPath) else {
                return errorJSON("Screenshot file not created")
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attrs[.size] as? Int64 ?? 0

            return successJSON([
                "path": outputPath,
                "size": fileSize,
                "message": "Fullscreen screenshot saved to \(outputPath)"
            ])
        } catch {
            return errorJSON("Failed to capture screenshot: \(error.localizedDescription)")
        }
    }
}
