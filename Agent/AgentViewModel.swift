@preconcurrency import Foundation
import AppKit

enum APIProvider: String, CaseIterable {
    case claude = "claude"
    case ollama = "ollama"

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .ollama: "Ollama"
        }
    }
}

@MainActor @Observable
final class AgentViewModel {
    var taskInput = ""
    var activityLog = ""
    var isRunning = false
    var isThinking = false
    var userServiceActive = false
    var rootServiceActive = false

    // One-time migration for stale defaults — runs before property defaults are evaluated
    @ObservationIgnored
    private static let _migrate: Void = {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "agentMigrationV2") else { return }
        if let stored = defaults.string(forKey: "ollamaEndpoint"),
           stored == "http://localhost:11434/v1/chat/completions" {
            defaults.set("https://ollama.com/api/chat", forKey: "ollamaEndpoint")
        }
        // Clear stale default model so user fetches from cloud
        if let model = defaults.string(forKey: "ollamaModel"), model == "llama3.1" {
            defaults.set("", forKey: "ollamaModel")
        }
        defaults.set(true, forKey: "agentMigrationV2")
    }()

    var selectedProvider: APIProvider = { _ = AgentViewModel._migrate; return APIProvider(rawValue: UserDefaults.standard.string(forKey: "agentProvider") ?? "claude") ?? .claude }() {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "agentProvider") }
    }

    // Claude settings
    var apiKey: String = UserDefaults.standard.string(forKey: "agentAPIKey") ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: "agentAPIKey") }
    }

    var selectedModel: String = UserDefaults.standard.string(forKey: "agentModel") ?? "claude-sonnet-4-20250514" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "agentModel") }
    }

    // Ollama settings
    var ollamaAPIKey: String = UserDefaults.standard.string(forKey: "ollamaAPIKey") ?? "" {
        didSet { UserDefaults.standard.set(ollamaAPIKey, forKey: "ollamaAPIKey") }
    }

    var ollamaEndpoint: String = UserDefaults.standard.string(forKey: "ollamaEndpoint") ?? "https://ollama.com/api/chat" {
        didSet { UserDefaults.standard.set(ollamaEndpoint, forKey: "ollamaEndpoint") }
    }

    var ollamaModel: String = UserDefaults.standard.string(forKey: "ollamaModel") ?? "" {
        didSet {
            UserDefaults.standard.set(ollamaModel, forKey: "ollamaModel")
            if !ollamaModel.isEmpty && oldValue != ollamaModel {
                let vision = selectedOllamaSupportsVision ? " (vision)" : ""
                appendLog("Switched to: \(ollamaModel)\(vision)")
                flushLog()
            }
        }
    }

    struct OllamaModelInfo: Identifiable {
        let id: String // same as name
        let name: String
        let supportsVision: Bool
    }

    var ollamaModels: [OllamaModelInfo] = []
    var isFetchingModels = false

    var selectedOllamaSupportsVision: Bool {
        ollamaModels.first(where: { $0.name == ollamaModel })?.supportsVision ?? false
    }

    func fetchOllamaModels() {
        let endpoint = ollamaEndpoint
        let apiKey = ollamaAPIKey
        isFetchingModels = true
        Task {
            defer { isFetchingModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: apiKey)
                ollamaModels = models
                // Auto-select first model if current selection is empty or not in list
                let names = models.map(\.name)
                if ollamaModel.isEmpty || (!names.isEmpty && !names.contains(ollamaModel)) {
                    ollamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchModels(endpoint: String, apiKey: String) async throws -> [OllamaModelInfo] {
        guard let chatURL = URL(string: endpoint) else { throw AgentError.invalidResponse }
        let baseDir = chatURL.deletingLastPathComponent().absoluteString

        guard let tagsURL = URL(string: baseDir + "tags") else { throw AgentError.invalidResponse }
        guard let showURL = URL(string: baseDir + "show") else { throw AgentError.invalidResponse }

        // 1. Fetch model list
        var tagsRequest = URLRequest(url: tagsURL)
        tagsRequest.httpMethod = "GET"
        tagsRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        if !apiKey.isEmpty {
            tagsRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        tagsRequest.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: tagsRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            throw AgentError.invalidResponse
        }

        let names = models.compactMap { $0["name"] as? String }.sorted()

        // 2. Check capabilities for each model via /api/show (in parallel)
        return await withTaskGroup(of: OllamaModelInfo?.self) { group in
            for name in names {
                group.addTask {
                    let hasVision = await Self.checkVision(model: name, showURL: showURL, apiKey: apiKey)
                    return OllamaModelInfo(id: name, name: name, supportsVision: hasVision)
                }
            }
            var results: [OllamaModelInfo] = []
            for await info in group {
                if let info { results.append(info) }
            }
            return results.sorted { $0.name < $1.name }
        }
    }

    /// Check if a model has "vision" in its capabilities via /api/show
    private nonisolated static func checkVision(model: String, showURL: URL, apiKey: String) async -> Bool {
        do {
            let body = try JSONSerialization.data(withJSONObject: ["model": model])
            var request = URLRequest(url: showURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.httpBody = body
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let capabilities = json["capabilities"] as? [String] else {
                return false
            }
            return capabilities.contains("vision")
        } catch {
            return false
        }
    }

    var attachedImages: [NSImage] = []
    private var attachedImagesBase64: [String] = []

    private var promptHistory: [String] = UserDefaults.standard.stringArray(forKey: "agentPromptHistory") ?? []
    private var historyIndex = -1
    private var savedInput = ""

    let helperService = HelperService()
    let userService = UserService()
    let history = TaskHistory.shared
    private var isCancelled = false
    private var runningTask: Task<Void, Never>?

    var daemonReady: Bool { helperService.helperReady }
    var agentReady: Bool { userService.userReady }
    var hasAttachments: Bool { !attachedImages.isEmpty }

    func registerDaemon() {
        let msg = helperService.registerHelper()
        appendLog(msg)
    }

    func registerAgent() {
        let msg = userService.registerUser()
        appendLog(msg)
    }

    func run() {
        let task = taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }

        // Stop any running task before starting a new one
        if isRunning {
            stop()
        }

        promptHistory.append(task)
        UserDefaults.standard.set(promptHistory, forKey: "agentPromptHistory")
        historyIndex = -1
        savedInput = ""
        taskInput = ""

        runningTask = Task {
            await executeTask(task)
        }
    }

    /// Navigate prompt history. direction: -1 = older (up arrow), 1 = newer (down arrow)
    func navigatePromptHistory(direction: Int) {
        guard !promptHistory.isEmpty else { return }

        if historyIndex == -1 {
            // Starting to browse — save current input
            savedInput = taskInput
            if direction == -1 {
                historyIndex = promptHistory.count - 1
            } else {
                return // already at the beginning, nothing newer
            }
        } else {
            historyIndex += direction
        }

        if historyIndex < 0 {
            // Went past the oldest — restore saved input
            historyIndex = -1
            taskInput = savedInput
            return
        }

        if historyIndex >= promptHistory.count {
            // Back to current input
            historyIndex = -1
            taskInput = savedInput
            return
        }

        taskInput = promptHistory[historyIndex]
    }

    func stop() {
        isCancelled = true
        runningTask?.cancel()
        runningTask = nil
        helperService.cancel()
        helperService.onOutput = nil
        userService.cancel()
        userService.onOutput = nil
        appendLog("Cancelled by user.")
        flushLog()
        isRunning = false
        isThinking = false
        userServiceActive = false
        rootServiceActive = false
    }

    func clearLog() {
        logBuffer = ""
        logFlushTask?.cancel()
        logFlushTask = nil
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

    // MARK: - Log Buffering

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var logBuffer = ""
    private var logFlushTask: Task<Void, Never>?

    private func appendLog(_ message: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        logBuffer += "[\(timestamp)] \(message)\n"
        scheduleLogFlush()
    }

    private func appendRawOutput(_ text: String) {
        guard !text.isEmpty else { return }
        logBuffer += text
        if !text.hasSuffix("\n") {
            logBuffer += "\n"
        }
        scheduleLogFlush()
    }

    private func scheduleLogFlush() {
        guard logFlushTask == nil else { return }
        logFlushTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            flushLog()
        }
    }

    private func flushLog() {
        logFlushTask?.cancel()
        logFlushTask = nil
        if !logBuffer.isEmpty {
            activityLog += logBuffer
            logBuffer = ""
        }
    }

    // MARK: - Task Execution Loop

    private func executeTask(_ prompt: String) async {
        isRunning = true
        isCancelled = false

        if !activityLog.isEmpty {
            logBuffer += "\n"
        }
        appendLog("--- New Task ---")
        appendLog("Task: \(prompt)")

        let historyContext = history.contextForPrompt()
        let provider = selectedProvider
        let modelName = provider == .claude ? selectedModel : ollamaModel
        let isVision = provider == .ollama && selectedOllamaSupportsVision
        appendLog("Model: \(provider.displayName) / \(modelName)\(isVision ? " (vision)" : "")")
        flushLog()

        let claude: ClaudeService? = provider == .claude
            ? ClaudeService(apiKey: apiKey, model: selectedModel, historyContext: historyContext) : nil
        let ollama: OllamaService? = provider == .ollama
            ? OllamaService(apiKey: ollamaAPIKey, model: ollamaModel, endpoint: ollamaEndpoint, supportsVision: isVision, historyContext: historyContext) : nil

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
        var consecutiveNoTool = 0

        var iterations = 0
        let maxIterations = 50

        while !isCancelled && iterations < maxIterations {
            iterations += 1

            do {
                isThinking = true
                let response: (content: [[String: Any]], stopReason: String)
                if let claude {
                    response = try await claude.send(messages: messages)
                } else if let ollama {
                    response = try await ollama.send(messages: messages)
                } else {
                    throw AgentError.noAPIKey
                }
                isThinking = false

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
                            flushLog()
                            history.add(TaskRecord(prompt: prompt, summary: summary, commandsRun: commandsRun))
                            isRunning = false
                            return
                        }

                        if name == "execute_command" || name == "execute_user_command" {
                            let command = input["command"] as? String ?? ""
                            let isPrivileged = (name == "execute_command")
                            commandsRun.append(command)
                            appendLog("\(isPrivileged ? "#" : "$") \(command)")
                            flushLog()

                            let result: (status: Int32, output: String)
                            if isPrivileged {
                                rootServiceActive = true
                                helperService.onOutput = { [weak self] chunk in
                                    self?.logBuffer += chunk
                                    self?.scheduleLogFlush()
                                }
                                result = await helperService.execute(command: command)
                                helperService.onOutput = nil
                                rootServiceActive = false
                            } else {
                                userServiceActive = true
                                userService.onOutput = { [weak self] chunk in
                                    self?.logBuffer += chunk
                                    self?.scheduleLogFlush()
                                }
                                result = await userService.execute(command: command)
                                userService.onOutput = nil
                                userServiceActive = false
                            }
                            flushLog()

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
                    consecutiveNoTool = 0
                } else if !hasToolUse {
                    consecutiveNoTool += 1
                    // Give the model up to 3 nudges to use tools before giving up
                    if consecutiveNoTool >= 3 {
                        appendLog("(model not using tools — stopping)")
                        break
                    }
                    messages.append(["role": "user", "content": "Continue. You must use execute_user_command or execute_command tools to perform actions. Call task_complete when finished."])
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

        flushLog()
        isRunning = false
        isThinking = false
        userServiceActive = false
        rootServiceActive = false
    }
}
