import Foundation

/// Thread-safe boolean flag for cross-thread cancellation checks.
final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return _value }
    func set() { lock.lock(); _value = true; lock.unlock() }
}

@MainActor @Observable
final class ScriptTab: Identifiable {
    let id: UUID
    let scriptName: String
    var activityLog: String = ""
    var isRunning: Bool = true
    var isCancelled: Bool = false {
        didSet { if isCancelled { _cancelFlag.set() } }
    }
    var exitCode: Int32?
    var cancelHandler: (() -> Void)?

    /// Thread-safe flag readable from any thread (for Sendable closures)
    nonisolated let _cancelFlag = AtomicFlag()

    // MARK: - Multi-Main-Tab LLM Config

    /// Non-nil when this is a "Main" tab with its own LLM provider/model
    var llmConfig: LLMConfig?
    /// Which main tab spawned this script tab (for LLM inheritance)
    var parentTabId: UUID?
    /// Whether this tab acts as an independent main tab
    var isMainTab: Bool { llmConfig != nil }
    /// Whether this is the dedicated Messages tab (for iMessage Agent! commands)
    var isMessagesTab: Bool = false
    /// The iMessage handle to reply to when a Messages tab task completes
    var replyHandle: String?
    /// Display name: LLM model name for main tabs, script name for script tabs
    var displayTitle: String { isMessagesTab ? "Messages" : llmConfig?.displayName ?? scriptName }

    // Log buffering (mirrors AgentViewModel pattern)
    var logBuffer = ""
    var logFlushTask: Task<Void, Never>?
    var streamLineCount = 0
    var streamTruncated = false

    // MARK: - LLM Conversation State

    var taskInput: String = ""
    var isLLMRunning: Bool = false
    var isLLMThinking: Bool = false
    var runningLLMTask: Task<Void, Never>?
    var llmMessages: [[String: Any]] = []

    // MARK: - Per-Tab Project Folder

    /// Each tab can have its own project folder
    var projectFolder: String = ""

    // MARK: - Per-Tab Prompt History

    var promptHistory: [String] = []
    var historyIndex: Int = -1
    var savedInput: String = ""

    // LLM streaming state
    var llmStreamBuffer: String = ""
    var llmStreamFlushTask: Task<Void, Never>?
    var llmStreamingStarted: Bool = false

    init(scriptName: String, id: UUID = UUID()) {
        self.id = id
        self.scriptName = scriptName
    }

    /// Create a new main tab with its own LLM configuration.
    init(llmConfig: LLMConfig, id: UUID = UUID()) {
        self.id = id
        self.scriptName = llmConfig.displayName
        self.llmConfig = llmConfig
        self.isRunning = false
    }

    /// Restore a tab from persisted SwiftData record.
    init(record: ScriptTabRecord) {
        self.id = record.tabId
        self.scriptName = record.scriptName
        self.activityLog = record.activityLog
        self.exitCode = record.exitCode == -999 ? nil : Int32(record.exitCode)
        self.isRunning = false
        self.isMessagesTab = record.isMessagesTab
        self.projectFolder = record.projectFolder
        // Restore LLM config if present
        if let json = record.llmConfigJSON, let data = json.data(using: .utf8) {
            self.llmConfig = try? JSONDecoder().decode(LLMConfig.self, from: data)
        }
        if let parentStr = record.parentTabIdString {
            self.parentTabId = UUID(uuidString: parentStr)
        }
    }

    // MARK: - Logging

    func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        let newlines = text.reduce(0) { $0 + ($1 == "\n" ? 1 : 0) }
        streamLineCount += max(newlines, 1)
        if streamLineCount > 1000 {
            if !streamTruncated {
                streamTruncated = true
                logBuffer += "...(output truncated at 1000 lines)...\n"
                scheduleFlush()
            }
            return
        }
        logBuffer += text
        if !text.hasSuffix("\n") { logBuffer += "\n" }
        scheduleFlush()
    }

    func appendLog(_ message: String) {
        let timestamp = AgentViewModel.timestampFormatter.string(from: Date())
        // Ensure timestamp always starts on a new line
        if !logBuffer.isEmpty && !logBuffer.hasSuffix("\n") {
            logBuffer += "\n"
        }
        logBuffer += "[\(timestamp)] \(message)\n"
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard logFlushTask == nil else { return }
        logFlushTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            flush()
        }
    }

    func flush() {
        logFlushTask?.cancel()
        logFlushTask = nil
        if !logBuffer.isEmpty {
            activityLog += logBuffer
            logBuffer = ""
        }
    }

    // MARK: - LLM Streaming

    func appendStreamDelta(_ delta: String) {
        if !llmStreamingStarted {
            llmStreamingStarted = true
            llmStreamBuffer = ""
        }
        llmStreamBuffer += delta
        scheduleLLMStreamFlush()
    }

    func flushStreamBuffer() {
        llmStreamFlushTask?.cancel()
        llmStreamFlushTask = nil
        if !llmStreamBuffer.isEmpty {
            // Write directly to logBuffer — don't use appendOutput which adds newlines per chunk
            logBuffer += llmStreamBuffer
            llmStreamBuffer = ""
            scheduleFlush()
        }
        llmStreamingStarted = false
    }

    private func scheduleLLMStreamFlush() {
        guard llmStreamFlushTask == nil else { return }
        llmStreamFlushTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            flushStreamBuffer()
        }
    }

    func resetLLMStreamCounters() {
        streamLineCount = 0
        streamTruncated = false
    }

    // MARK: - Prompt History Navigation

    func addToHistory(_ prompt: String) {
        promptHistory.append(prompt)
        historyIndex = -1
        savedInput = ""
    }

    func navigateHistory(direction: Int) {
        guard !promptHistory.isEmpty else { return }

        if historyIndex == -1 {
            savedInput = taskInput
            if direction == -1 {
                historyIndex = promptHistory.count - 1
            } else {
                return
            }
        } else {
            historyIndex += direction
        }

        if historyIndex < 0 {
            historyIndex = -1
            taskInput = savedInput
            return
        }

        if historyIndex >= promptHistory.count {
            historyIndex = -1
            taskInput = savedInput
            return
        }

        taskInput = promptHistory[historyIndex]
    }
}
