@preconcurrency import Foundation
import AppKit

@MainActor @Observable
final class AgentViewModel {
    var taskInput = ""
    var activityLog = ""
    var isRunning = false

    var apiKey: String = UserDefaults.standard.string(forKey: "agentAPIKey") ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: "agentAPIKey") }
    }

    var selectedModel: String = UserDefaults.standard.string(forKey: "agentModel") ?? "claude-sonnet-4-20250514" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "agentModel") }
    }

    var attachedImages: [NSImage] = []
    private var attachedImagesBase64: [String] = []

    let helperService = HelperService()
    let history = TaskHistory.shared
    private var isCancelled = false

    var daemonReady: Bool { helperService.helperReady }
    var hasAttachments: Bool { !attachedImages.isEmpty }

    func registerDaemon() {
        let msg = helperService.registerHelper()
        appendLog(msg)
    }

    func run() {
        let task = taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }
        taskInput = ""

        Task {
            await executeTask(task)
        }
    }

    func stop() {
        isCancelled = true
        helperService.cancel()
        appendLog("Cancelled by user.")
        isRunning = false
    }

    func clearLog() {
        activityLog = ""
    }

    // MARK: - Screenshot

    func captureScreenshot() {
        let tempPath = NSTemporaryDirectory() + "agent_screenshot_\(UUID().uuidString).png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", tempPath]  // interactive selection

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            appendLog("Screenshot failed: \(error.localizedDescription)")
            return
        }

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tempPath),
              let image = NSImage(contentsOfFile: tempPath),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            // User cancelled the capture or file not found
            return
        }

        attachedImages.append(image)
        attachedImagesBase64.append(pngData.base64EncodedString())
        try? FileManager.default.removeItem(atPath: tempPath)
    }

    func removeAttachment(at index: Int) {
        guard attachedImages.indices.contains(index) else { return }
        attachedImages.remove(at: index)
        attachedImagesBase64.remove(at: index)
    }

    func removeAllAttachments() {
        attachedImages.removeAll()
        attachedImagesBase64.removeAll()
    }

    /// Try all pasteboard formats to grab an image.
    /// Returns true if image data was found (encoding happens async in background).
    @discardableResult
    func pasteImageFromClipboard() -> Bool {
        let pb = NSPasteboard.general

        var rawData: Data?

        // Try raw data types first (avoids full NSImage deserialization overhead)
        for type in [NSPasteboard.PasteboardType.png,
                     NSPasteboard.PasteboardType.tiff,
                     NSPasteboard.PasteboardType(rawValue: "public.jpeg")] {
            if let data = pb.data(forType: type) {
                rawData = data
                break
            }
        }

        // Try NSImage as fallback
        if rawData == nil,
           let images = pb.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let img = images.first,
           let tiff = img.tiffRepresentation {
            rawData = tiff
        }

        // Try file URLs (e.g. screenshot file copied from Finder)
        if rawData == nil,
           let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ["png", "jpg", "jpeg", "tiff", "bmp", "gif"].contains(ext),
                   let data = try? Data(contentsOf: url) {
                    rawData = data
                    break
                }
            }
        }

        guard let imageData = rawData else { return false }

        // Encode on a background thread to avoid blocking the main thread
        Task {
            let base64 = await Self.encodeImageToBase64(imageData)
            guard let base64 else { return }
            if let image = NSImage(data: imageData) {
                attachedImages.append(image)
                attachedImagesBase64.append(base64)
            }
        }

        return true
    }

    /// Encode image data to a base64 PNG string off the main thread.
    /// Downscales images larger than 2048px to prevent memory issues.
    private static nonisolated func encodeImageToBase64(_ data: Data) async -> String? {
        guard let bitmap = NSBitmapImageRep(data: data) else { return nil }

        let maxDim = 2048
        let w = bitmap.pixelsWide
        let h = bitmap.pixelsHigh

        if w > maxDim || h > maxDim {
            let scale = min(Double(maxDim) / Double(w), Double(maxDim) / Double(h))
            let newW = Int(Double(w) * scale)
            let newH = Int(Double(h) * scale)

            guard let cgImage = bitmap.cgImage,
                  let ctx = CGContext(
                      data: nil, width: newW, height: newH,
                      bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return nil }

            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))

            guard let resizedCG = ctx.makeImage() else { return nil }
            let resizedBitmap = NSBitmapImageRep(cgImage: resizedCG)
            guard let pngData = resizedBitmap.representation(using: .png, properties: [:]) else { return nil }
            return pngData.base64EncodedString()
        }

        guard let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return pngData.base64EncodedString()
    }

    // MARK: - Task Execution Loop

    private func executeTask(_ prompt: String) async {
        isRunning = true
        isCancelled = false

        if !activityLog.isEmpty {
            activityLog += "\n"
        }
        appendLog("--- New Task ---")
        appendLog("Task: \(prompt)")

        let historyContext = history.contextForPrompt()
        let claude = ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext)

        var messages: [[String: Any]]

        if !attachedImagesBase64.isEmpty {
            appendLog("(\(attachedImagesBase64.count) screenshot(s) attached)")
            var contentBlocks: [[String: Any]] = attachedImagesBase64.map { base64 in
                [
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/png",
                        "data": base64
                    ] as [String: Any]
                ]
            }
            contentBlocks.append(["type": "text", "text": prompt])
            messages = [["role": "user", "content": contentBlocks]]
            // Clear attachments after use
            attachedImages.removeAll()
            attachedImagesBase64.removeAll()
        } else {
            messages = [["role": "user", "content": prompt]]
        }

        var commandsRun: [String] = []
        var completionSummary = ""

        var iterations = 0
        let maxIterations = 50

        while !isCancelled && iterations < maxIterations {
            iterations += 1

            do {
                let response = try await claude.send(messages: messages)

                var toolResults: [[String: Any]] = []
                var hasToolUse = false

                for block in response.content {
                    guard let type = block["type"] as? String else { continue }

                    if type == "text", let text = block["text"] as? String {
                        appendLog(text)
                    } else if type == "tool_use" {
                        hasToolUse = true
                        guard let toolId = block["id"] as? String,
                              let name = block["name"] as? String,
                              let input = block["input"] as? [String: Any] else { continue }

                        if name == "task_complete" {
                            let summary = input["summary"] as? String ?? "Done"
                            completionSummary = summary
                            appendLog("Completed: \(summary)")
                            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun))
                            isRunning = false
                            return
                        }

                        if name == "execute_command" {
                            let command = input["command"] as? String ?? ""
                            commandsRun.append(command)
                            appendLog("$ \(command)")

                            let result = await helperService.execute(command: command)

                            if !result.output.isEmpty {
                                activityLog += result.output
                                if !result.output.hasSuffix("\n") {
                                    activityLog += "\n"
                                }
                            }

                            if result.status != 0 {
                                appendLog("exit code: \(result.status)")
                            }

                            let toolOutput: String
                            if result.output.isEmpty {
                                toolOutput = "(no output, exit code: \(result.status))"
                            } else {
                                toolOutput = result.output
                            }

                            // Truncate very long outputs for the API
                            let truncated = toolOutput.count > 10000
                                ? String(toolOutput.prefix(10000)) + "\n...(truncated)"
                                : toolOutput

                            toolResults.append([
                                "type": "tool_result",
                                "tool_use_id": toolId,
                                "content": truncated
                            ])
                        }
                    }
                }

                // Add assistant response to conversation
                messages.append(["role": "assistant", "content": response.content])

                if hasToolUse && !toolResults.isEmpty {
                    messages.append(["role": "user", "content": toolResults])
                } else {
                    break
                }

                if response.stopReason == "end_turn" && !hasToolUse {
                    break
                }

            } catch {
                appendLog("Error: \(error.localizedDescription)")
                break
            }
        }

        if iterations >= maxIterations {
            appendLog("Reached maximum iterations (\(maxIterations))")
        }

        // Save partial history if task didn't call task_complete
        if completionSummary.isEmpty && !commandsRun.isEmpty {
            history.add(TaskRecord(prompt: prompt, summary: "(incomplete)", commandsRun: commandsRun))
        }

        isRunning = false
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        activityLog += "[\(timestamp)] \(message)\n"
    }
}
