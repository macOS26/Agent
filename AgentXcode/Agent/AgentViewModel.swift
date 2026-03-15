@preconcurrency import Foundation
import AppKit
import SQLite3

enum APIProvider: String, CaseIterable {
    case claude = "claude"
    case ollama = "ollama"
    case localOllama = "localOllama"

    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .ollama: "Ollama"
        case .localOllama: "Local Ollama"
        }
    }
}

@MainActor @Observable
final class AgentViewModel {
    var taskInput = ""
    
    // Stored property drives live UI; ChatHistoryStore persists across launches via SwiftData
    var activityLog = ChatHistoryStore.shared.buildActivityLogText(maxTasks: 3)
    var isRunning = false
    var isThinking = false
    var userServiceActive = false
    var rootServiceActive = false
    var userWasActive = false
    var rootWasActive = false
    var rootEnabled: Bool = UserDefaults.standard.object(forKey: "agentRootEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(rootEnabled, forKey: "agentRootEnabled")
            if !rootEnabled {
                // Kill and unregister the daemon for security
                helperService.shutdownDaemon()
                appendLog("Launch Daemon: shut down for security")
            }
        }
    }

    var selectedProvider: APIProvider = { APIProvider(rawValue: UserDefaults.standard.string(forKey: "agentProvider") ?? "ollama") ?? .ollama }() {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "agentProvider")
            if selectedProvider == .ollama && ollamaModels.isEmpty {
                fetchOllamaModels()
            }
            if selectedProvider == .localOllama && localOllamaModels.isEmpty {
                fetchLocalOllamaModels()
            }
            if selectedProvider == .claude && availableClaudeModels.isEmpty {
                Task { await fetchClaudeModels() }
            }
        }
    }

    // Claude settings - stored securely in Keychain
    var apiKey: String = KeychainService.shared.getClaudeAPIKey() ?? "" {
        didSet { KeychainService.shared.setClaudeAPIKey(apiKey) }
    }

    var selectedModel: String = UserDefaults.standard.string(forKey: "agentModel") ?? "claude-sonnet-4-20250514" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "agentModel") }
    }

    // Ollama settings - API key stored securely in Keychain
    var ollamaAPIKey: String = KeychainService.shared.getOllamaAPIKey() ?? "" {
        didSet { KeychainService.shared.setOllamaAPIKey(ollamaAPIKey) }
    }

    // Tavily web search API key (for Ollama providers)
    var tavilyAPIKey: String = KeychainService.shared.getTavilyAPIKey() ?? "" {
        didSet { KeychainService.shared.setTavilyAPIKey(tavilyAPIKey) }
    }

    let ollamaEndpoint = "https://ollama.com/api/chat"

    var maxHistoryBeforeSummary: Int = UserDefaults.standard.object(forKey: "agentMaxHistory") as? Int ?? 10 {
        didSet { UserDefaults.standard.set(maxHistoryBeforeSummary, forKey: "agentMaxHistory") }
    }

    var visibleTaskCount: Int = UserDefaults.standard.object(forKey: "agentVisibleTasks") as? Int ?? 3 {
        didSet { UserDefaults.standard.set(visibleTaskCount, forKey: "agentVisibleTasks") }
    }

    static let iterationOptions = [25, 50, 75, 100, 150, 200]

    var maxIterations: Int = UserDefaults.standard.object(forKey: "agentMaxIterations") as? Int ?? 50 {
        didSet { UserDefaults.standard.set(maxIterations, forKey: "agentMaxIterations") }
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

    private static let defaultOllamaModels: [OllamaModelInfo] = [
        OllamaModelInfo(id: "nemotron-3-super", name: "nemotron-3-super", supportsVision: false),
        OllamaModelInfo(id: "qwen3.5:397b", name: "qwen3.5:397b", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2.5", name: "minimax-m2.5", supportsVision: false),
        OllamaModelInfo(id: "glm-5", name: "glm-5", supportsVision: false),
        OllamaModelInfo(id: "kimi-k2.5", name: "kimi-k2.5", supportsVision: true),
        OllamaModelInfo(id: "glm-4.7", name: "glm-4.7", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2.1", name: "minimax-m2.1", supportsVision: false),
        OllamaModelInfo(id: "gemini-3-flash-preview", name: "gemini-3-flash-preview", supportsVision: true),
        OllamaModelInfo(id: "nemotron-3-nano:30b", name: "nemotron-3-nano:30b", supportsVision: false),
        OllamaModelInfo(id: "devstral-small-2:24b", name: "devstral-small-2:24b", supportsVision: false),
        OllamaModelInfo(id: "devstral-2:123b", name: "devstral-2:123b", supportsVision: false),
        OllamaModelInfo(id: "ministral-3:8b", name: "ministral-3:8b", supportsVision: false),
        OllamaModelInfo(id: "ministral-3:14b", name: "ministral-3:14b", supportsVision: false),
        OllamaModelInfo(id: "deepseek-v3.2", name: "deepseek-v3.2", supportsVision: false),
        OllamaModelInfo(id: "mistral-large-3:675b", name: "mistral-large-3:675b", supportsVision: false),
        OllamaModelInfo(id: "deepseek-v3.1:671b", name: "deepseek-v3.1:671b", supportsVision: false),
        OllamaModelInfo(id: "cogito-2.1:671b", name: "cogito-2.1:671b", supportsVision: false),
        OllamaModelInfo(id: "minimax-m2", name: "minimax-m2", supportsVision: false),
        OllamaModelInfo(id: "glm-4.6", name: "glm-4.6", supportsVision: false),
        OllamaModelInfo(id: "qwen3-vl:235b-instruct", name: "qwen3-vl:235b-instruct", supportsVision: true),
        OllamaModelInfo(id: "qwen3-vl:235b", name: "qwen3-vl:235b", supportsVision: true),
        OllamaModelInfo(id: "qwen3-next:80b", name: "qwen3-next:80b", supportsVision: false),
        OllamaModelInfo(id: "kimi-k2:1t", name: "kimi-k2:1t", supportsVision: false),
        OllamaModelInfo(id: "gpt-oss:120b", name: "gpt-oss:120b", supportsVision: false),
        OllamaModelInfo(id: "qwen3-coder:480b", name: "qwen3-coder:480b", supportsVision: false),
        OllamaModelInfo(id: "gemma3:27b", name: "gemma3:27b", supportsVision: true),
        OllamaModelInfo(id: "gemma3:12b", name: "gemma3:12b", supportsVision: true),
        OllamaModelInfo(id: "gemma3:4b", name: "gemma3:4b", supportsVision: true),
        OllamaModelInfo(id: "qwen3-coder-next", name: "qwen3-coder-next", supportsVision: false),
        OllamaModelInfo(id: "gpt-oss:20b", name: "gpt-oss:20b", supportsVision: false)

    ]
    // MARK: - Claude Models

    struct ClaudeModelInfo: Identifiable, Codable {
        let id: String
        let name: String
        let displayName: String
        let createdAt: String?
        let description: String?

        var formattedDisplayName: String {
            if let created = createdAt {
                let dateStr = String(created.prefix(10))
                return "\(displayName) (\(dateStr))"
            }
            return displayName
        }
    }

    var availableClaudeModels: [ClaudeModelInfo] = []

    private static let defaultClaudeModels: [ClaudeModelInfo] = [
        ClaudeModelInfo(id: "claude-sonnet-4-6", name: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", createdAt: "2026-02-17", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-6", name: "claude-opus-4-6", displayName: "Claude Opus 4.6", createdAt: "2026-02-04", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-5-20251101", name: "claude-opus-4-5-20251101", displayName: "Claude Opus 4.5", createdAt: "2025-11-24", description: nil),
        ClaudeModelInfo(id: "claude-haiku-4-5-20251001", name: "claude-haiku-4-5-20251001", displayName: "Claude Haiku 4.5", createdAt: "2025-10-15", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4-5-20250929", name: "claude-sonnet-4-5-20250929", displayName: "Claude Sonnet 4.5", createdAt: "2025-09-29", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-1-20250805", name: "claude-opus-4-1-20250805", displayName: "Claude Opus 4.1", createdAt: "2025-08-05", description: nil),
        ClaudeModelInfo(id: "claude-opus-4-20250514", name: "claude-opus-4-20250514", displayName: "Claude Opus 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-sonnet-4-20250514", name: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4", createdAt: "2025-05-22", description: nil),
        ClaudeModelInfo(id: "claude-3-haiku-20240307", name: "claude-3-haiku-20240307", displayName: "Claude Haiku 3", createdAt: "2024-03-07", description: nil)
    ]

    var ollamaModels: [OllamaModelInfo] = []
    var isFetchingModels = false

    var selectedOllamaSupportsVision: Bool {
        ollamaModels.first(where: { $0.name == ollamaModel })?.supportsVision ?? false
    }

    // Local Ollama settings
    var localOllamaEndpoint: String = UserDefaults.standard.string(forKey: "localOllamaEndpoint") ?? "http://localhost:11434/api/chat" {
        didSet { UserDefaults.standard.set(localOllamaEndpoint, forKey: "localOllamaEndpoint") }
    }

    var localOllamaModel: String = UserDefaults.standard.string(forKey: "localOllamaModel") ?? "" {
        didSet {
            UserDefaults.standard.set(localOllamaModel, forKey: "localOllamaModel")
            if !localOllamaModel.isEmpty && oldValue != localOllamaModel {
                let vision = selectedLocalOllamaSupportsVision ? " (vision)" : ""
                appendLog("Switched to: \(localOllamaModel)\(vision)")
                flushLog()
            }
        }
    }

    var localOllamaModels: [OllamaModelInfo] = []
    var isFetchingLocalModels = false

    var selectedLocalOllamaSupportsVision: Bool {
        localOllamaModels.first(where: { $0.name == localOllamaModel })?.supportsVision ?? false
    }

    var attachedImages: [NSImage] = []
    var attachedImagesBase64: [String] = []

    private var promptHistory: [String] = UserDefaults.standard.stringArray(forKey: "agentPromptHistory") ?? []
    private var historyIndex = -1
    private var savedInput = ""

    let helperService = HelperService()
    let userService = UserService()
    let scriptService = ScriptService()
    let history = TaskHistory.shared
    var isCancelled = false
    private var runningTask: Task<Void, Never>?
    @ObservationIgnored private var terminationObserver: Any?

    // MARK: - Messages Monitor
    var messagesMonitorEnabled: Bool = UserDefaults.standard.object(forKey: "agentMessagesMonitor") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(messagesMonitorEnabled, forKey: "agentMessagesMonitor")
            if messagesMonitorEnabled {
                startMessagesMonitor()
            } else {
                stopMessagesMonitor()
            }
        }
    }
    private var messagesMonitorTask: Task<Void, Never>?
    /// ROWID of the last message we've already processed
    private var lastSeenMessageROWID: Int = 0
    /// Briefly true during each poll cycle so the StatusDot pulses on the timer
    var messagesPolling = false

    /// Chat recipients discovered from Messages database
    struct MessageRecipient: Identifiable, Hashable {
        let id: String        // handle id (phone/email) — used as stable key for filtering
        let displayName: String
        let service: String   // "iMessage" or "SMS"
    }
    var messageRecipients: [MessageRecipient] = []
    /// Set of handle IDs (phone/email) the user has enabled for monitoring
    var enabledHandleIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "agentEnabledHandleIds") ?? []
        return Set(saved)
    }() {
        didSet { UserDefaults.standard.set(Array(enabledHandleIds), forKey: "agentEnabledHandleIds") }
    }

    // MARK: - Logging State

    static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var logBuffer = ""
    var logFlushTask: Task<Void, Never>?
    var logPersistTask: Task<Void, Never>?
    var streamLineCount = 0
    var streamTruncated = false
    static let outputLineOptions = [10, 50, 75, 100, 150, 200, 250, 500, 750, 1000, 1500]
    var maxOutputLines: Int = UserDefaults.standard.object(forKey: "agentMaxOutputLines") as? Int ?? 1000 {
        didSet { UserDefaults.standard.set(maxOutputLines, forKey: "agentMaxOutputLines") }
    }

    static let readPreviewOptions = [3, 10, 50, 100, 250, 500, 750, 1000]
    var readFilePreviewLines: Int = UserDefaults.standard.object(forKey: "agentReadFilePreviewLines") as? Int ?? 3 {
        didSet { UserDefaults.standard.set(readFilePreviewLines, forKey: "agentReadFilePreviewLines") }
    }

    // LLM streaming state
    var streamBuffer = ""
    var streamFlushTask: Task<Void, Never>?
    var streamingTextStarted = false
    static let maxLogSize = 60_000
    var recentOutputHashes: Set<Int> = []

    // MARK: - Image snapshot cache (persists across launches)

    static let logImageCacheDir: URL = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Agent/log_images") }
        let dir = caches.appendingPathComponent("Agent/log_images")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let imagePathRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(/[^\s"'<>]+\.(?:jpg|jpeg|png|gif|tiff|bmp|webp|heic))"#,
        options: .caseInsensitive
    )

    // MARK: - Off-Main-Thread Helper

    /// Run synchronous work off the main thread to avoid blocking the UI.
    static func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
        await Task.detached { work() }.value
    }

    // MARK: - Computed Properties

    var daemonReady: Bool { helperService.helperReady }
    var agentReady: Bool { userService.userReady }
    var hasAttachments: Bool { !attachedImages.isEmpty }

    // MARK: - Init

    init() {
        // Restore ~/Documents/Agent/ folder and bundled resources if missing
        scriptService.ensurePackage()

        // Cancel any orphaned processes from a previous app session
        let defaults = UserDefaults.standard
        if let oldHelperID = defaults.string(forKey: "lastHelperInstanceID") {
            HelperService.cancelProcess(instanceID: oldHelperID)
        }
        if let oldUserID = defaults.string(forKey: "lastUserInstanceID") {
            UserService.cancelProcess(instanceID: oldUserID)
        }
        // Persist current instanceIDs so next launch can clean up
        defaults.set(helperService.instanceID, forKey: "lastHelperInstanceID")
        defaults.set(userService.instanceID, forKey: "lastUserInstanceID")

        // Cancel running processes on app quit
        let helperID = helperService.instanceID
        let userID = userService.instanceID
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { _ in
            HelperService.cancelProcess(instanceID: helperID)
            UserService.cancelProcess(instanceID: userID)
            UserDefaults.standard.removeObject(forKey: "lastHelperInstanceID")
            UserDefaults.standard.removeObject(forKey: "lastUserInstanceID")
        }

        // Auto-fetch models on launch based on provider
        if selectedProvider == .claude {
            Task { await fetchClaudeModels() }
        } else if selectedProvider == .ollama {
            fetchOllamaModels()
        } else if selectedProvider == .localOllama {
            fetchLocalOllamaModels()
        }

        // Xcode Command Line Tools check is handled by DependencyOverlay in ContentView

        // Resume Messages monitor if it was enabled
        if messagesMonitorEnabled {
            // Delay start so UserService is connected first
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                startMessagesMonitor()
            }
        }

        // Test daemon connectivity on startup — auto-fix if not responding
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            appendLog("Warming up the engines...")
            var userOK = await userService.ping()
            appendLog("User agent: \(userOK ? "ping OK" : "no response")")
            var daemonOK = false
            if rootEnabled {
                daemonOK = await helperService.ping()
                appendLog("Launch Daemon: \(daemonOK ? "ping OK" : "no response")")
            } else {
                appendLog("Launch Daemon: disabled")
            }
            if !userOK {
                appendLog("User agent: mending...")
                _ = userService.restartAgent()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                userOK = await userService.ping()
                appendLog("User agent: \(userOK ? "mended — ping OK" : "still NOT responding")")
            }
            if rootEnabled && !daemonOK {
                appendLog("Launch Daemon: mending...")
                _ = helperService.restartDaemon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                daemonOK = await helperService.ping()
                appendLog("Launch Daemon: \(daemonOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !userOK || (rootEnabled && !daemonOK) {
                appendLog("Click Register to restart services")
            }
        }
    }

    // MARK: - Registration

    func registerDaemon() {
        let msg = helperService.registerHelper()
        appendLog(msg)
    }

    func registerAgent() {
        let msg = userService.registerUser()
        appendLog(msg)
    }

    func testConnection() {
        appendLog("Testing connections...")
        Task {
            var userOK = await userService.ping()
            appendLog("User agent: \(userOK ? "ping OK" : "no response")")
            var daemonOK = await helperService.ping()
            appendLog("Launch Daemon: \(daemonOK ? "ping OK" : "no response")")
            if !userOK {
                appendLog("User agent: mending...")
                _ = userService.restartAgent()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                userOK = await userService.ping()
                appendLog("User agent: \(userOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !daemonOK {
                appendLog("Launch Daemon: mending...")
                _ = helperService.restartDaemon()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                daemonOK = await helperService.ping()
                appendLog("Launch Daemon: \(daemonOK ? "mended — ping OK" : "still NOT responding")")
            }
            if !userOK || !daemonOK {
                appendLog("Click Register to restart services")
            }
        }
    }

    // MARK: - Run / Stop

    func run() {
        let task = taskInput.trimmingCharacters(in: .whitespaces)
        guard !task.isEmpty else { return }

        // Handle /clear command
        if task.lowercased() == "/clear" {
            taskInput = ""
            clearLog()
            return
        }

        // Stop any running task before starting a new one
        if isRunning {
            stop(silent: true)
        }

        // Start a new task in SwiftData chat history
        ChatHistoryStore.shared.startNewTask(prompt: task)
        
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

    func stop(silent: Bool = false) {
        isCancelled = true
        runningTask?.cancel()
        runningTask = nil
        helperService.cancel()
        helperService.onOutput = nil
        userService.cancel()
        userService.onOutput = nil
        if !silent {
            appendLog("Cancelled by user.")
        }
        flushLog()
        persistLogNow()
        // End the current task in chat history
        ChatHistoryStore.shared.endCurrentTask(cancelled: !silent)
        isRunning = false
        isThinking = false
        userServiceActive = false
        rootServiceActive = false
        userWasActive = false
        rootWasActive = false
    }

    // MARK: - Messages Monitor

    func startMessagesMonitor() {
        stopMessagesMonitor()
        refreshMessageRecipients()
        appendLog("Messages monitor: ON")
        flushLog()

        messagesMonitorTask = Task { [weak self] in
            guard let self else { return }
            // Seed the last-seen ROWID so we only act on NEW messages
            await self.seedLastSeenROWID()

            // Pulse on startup
            self.flashMessagesDot()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // poll every 5s
                guard !Task.isCancelled else { break }
                await self.pollMessages()
            }
        }
    }

    func stopMessagesMonitor() {
        messagesMonitorTask?.cancel()
        messagesMonitorTask = nil
        messagesPolling = false
    }

    /// Briefly flash the Messages StatusDot green.
    private func flashMessagesDot() {
        messagesPolling = true
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            messagesPolling = false
        }
    }

    // Stored outside @MainActor so nonisolated static methods can access it
    private nonisolated static let messagesDBPath = NSHomeDirectory() + "/Library/Messages/chat.db"

    /// Decode attributedBody blob (typedstream/NSArchiver format).
    /// NSUnarchiver is the only way to decode the typedstream format used by the Messages database.
    private nonisolated static func decodeAttributedBody(_ data: Data) -> NSAttributedString? {
        guard let cls = NSClassFromString("NSUnarchiver") else { return nil }
        let sel = NSSelectorFromString("unarchiveObjectWithData:")
        guard let method = class_getClassMethod(cls, sel) else { return nil }
        typealias Fn = @convention(c) (AnyClass, Selector, NSData) -> AnyObject?
        let imp = method_getImplementation(method)
        let f = unsafeBitCast(imp, to: Fn.self)
        return f(cls, sel, data as NSData) as? NSAttributedString
    }

    /// Read new messages directly from chat.db using SQLite3 C API.
    private nonisolated static func queryMessages(afterROWID: Int) -> [(rowid: Int, text: String, handleId: String)] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(messagesDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT m.ROWID, m.text, m.attributedBody, COALESCE(h.id, '') \
        FROM message m LEFT JOIN handle h ON h.ROWID = m.handle_id \
        WHERE m.ROWID > ?1 AND m.is_from_me = 0 ORDER BY m.ROWID ASC LIMIT 10
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, Int64(afterROWID))

        var results: [(rowid: Int, text: String, handleId: String)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowid = Int(sqlite3_column_int64(stmt, 0))
            let handleId = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""

            // Try the `text` column first
            var text: String?
            if let cStr = sqlite3_column_text(stmt, 1) {
                let s = String(cString: cStr)
                if !s.isEmpty { text = s }
            }

            // Fall back to decoding attributedBody blob (NSArchiver typedstream format)
            if text == nil, let blobPtr = sqlite3_column_blob(stmt, 2) {
                let blobLen = Int(sqlite3_column_bytes(stmt, 2))
                let data = Data(bytes: blobPtr, count: blobLen)
                if let attrStr = Self.decodeAttributedBody(data) {
                    let s = attrStr.string
                    if !s.isEmpty { text = s }
                }
            }

            results.append((rowid: rowid, text: text ?? "", handleId: handleId))
        }
        return results
    }

    /// Query all unique recipients (handles) from the Messages database.
    nonisolated static func queryRecipients() -> [MessageRecipient] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(messagesDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }

        let sql = """
        SELECT h.id, h.service, COALESCE(c.display_name, '') \
        FROM handle h \
        LEFT JOIN chat_handle_join chj ON chj.handle_id = h.ROWID \
        LEFT JOIN chat c ON c.ROWID = chj.chat_id \
        ORDER BY h.ROWID DESC
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var seen = Set<String>()
        var results: [MessageRecipient] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let handleId = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? ""
            guard !handleId.isEmpty, !seen.contains(handleId) else { continue }
            seen.insert(handleId)

            let service = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            let displayName = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""

            let name = displayName.isEmpty ? handleId : "\(displayName) (\(handleId))"
            results.append(MessageRecipient(id: handleId, displayName: name, service: service))
        }
        return results
    }

    /// Refresh the recipients list from the Messages database.
    func refreshMessageRecipients() {
        Task {
            let recipients = await Self.offMain({ Self.queryRecipients() })
            self.messageRecipients = recipients
        }
    }

    /// Query for the max ROWID in the Messages database.
    private nonisolated static func maxMessageROWID() -> Int? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(messagesDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MAX(ROWID) FROM message", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// Seed the ROWID cursor so we only process messages arriving after monitor starts.
    private func seedLastSeenROWID() async {
        if let rowid = await Self.offMain({ Self.maxMessageROWID() }) {
            lastSeenMessageROWID = rowid
            appendLog("Messages monitor: seeded at ROWID \(rowid)")
        } else {
            appendLog("Messages monitor: failed to read chat.db")
        }
        flushLog()
    }

    /// Poll for new incoming messages; log from enabled handles, act on "Agent!" prefix.
    private func pollMessages() async {
        let after = lastSeenMessageROWID
        let enabled = enabledHandleIds
        let rows = await Self.offMain({ Self.queryMessages(afterROWID: after) })
        guard !rows.isEmpty else { return }

        for row in rows {
            lastSeenMessageROWID = row.rowid

            guard !row.text.isEmpty else { continue }

            // Skip messages from handles the user hasn't enabled (if any are selected)
            if !enabled.isEmpty && !enabled.contains(row.handleId) { continue }

            // Pulse the dot and show incoming message in the log
            flashMessagesDot()
            appendLog("iMessage: \(row.text)")
            flushLog()

            // Only act on "Agent!" commands
            guard row.text.hasPrefix("Agent!") else { continue }
            let stripped = row.text.dropFirst(6) // drop "Agent!"
            let prompt = stripped.hasPrefix(" ")
                ? String(stripped.dropFirst()).trimmingCharacters(in: .whitespaces)
                : String(stripped).trimmingCharacters(in: .whitespaces)
            guard !prompt.isEmpty, !isRunning else { continue }

            appendLog("Agent! prompt: \(prompt)")
            flushLog()
            taskInput = prompt
            run()
        }
    }

    // MARK: - Model Fetching

    func fetchClaudeModels() async {
        guard !apiKey.isEmpty else {
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
            return
        }

        do {
            let models = try await Self.fetchClaudeModelsFromAPI(apiKey: apiKey)
            await MainActor.run {
                self.availableClaudeModels = models.isEmpty ? Self.defaultClaudeModels : models
            }
        } catch {
            print("Error fetching Claude models: \(error)")
            await MainActor.run {
                self.availableClaudeModels = Self.defaultClaudeModels
            }
        }
    }

    private static func fetchClaudeModelsFromAPI(apiKey: String) async throws -> [ClaudeModelInfo] {
        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AgentError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "API error")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsData = json["data"] as? [[String: Any]] else {
            return defaultClaudeModels
        }

        let models = modelsData.compactMap { modelData -> ClaudeModelInfo? in
            guard let id = modelData["id"] as? String else { return nil }
            let displayName = modelData["display_name"] as? String ?? id
            let createdAt = modelData["created_at"] as? String
            let description = modelData["description"] as? String

            return ClaudeModelInfo(
                id: id,
                name: displayName,
                displayName: displayName,
                createdAt: createdAt,
                description: description
            )
        }

        return models.isEmpty ? defaultClaudeModels : models
    }

    func fetchOllamaModels() {
        let endpoint = ollamaEndpoint
        let apiKey = ollamaAPIKey
        isFetchingModels = true
        Task {
            defer { isFetchingModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: apiKey)
                ollamaModels = models.isEmpty ? Self.defaultOllamaModels : models
                // Auto-select first model if current selection is empty or not in list
                let names = ollamaModels.map(\.name)
                if ollamaModel.isEmpty || (!names.isEmpty && !names.contains(ollamaModel)) {
                    ollamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch models: \(error.localizedDescription)")
                ollamaModels = Self.defaultOllamaModels
            }
        }
    }

    func fetchLocalOllamaModels() {
        let endpoint = localOllamaEndpoint
        isFetchingLocalModels = true
        Task {
            defer { isFetchingLocalModels = false }
            do {
                let models = try await Self.fetchModels(endpoint: endpoint, apiKey: "")
                localOllamaModels = models
                let names = models.map(\.name)
                if localOllamaModel.isEmpty || (!names.isEmpty && !names.contains(localOllamaModel)) {
                    localOllamaModel = names.first ?? ""
                }
            } catch {
                appendLog("Failed to fetch local models: \(error.localizedDescription)")
            }
        }
    }

    private nonisolated static func fetchModels(endpoint: String, apiKey: String) async throws -> [OllamaModelInfo] {
        let effectiveEndpoint = endpoint.isEmpty ? "http://localhost:11434/api/chat" : endpoint
        guard let chatURL = URL(string: effectiveEndpoint) else { throw AgentError.invalidResponse }
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
}
