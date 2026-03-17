import Foundation
import SwiftData

/// A single log entry in the chat history
@Model
final class ChatMessage {
    var timestamp: Date
    var content: String
    var isStreaming: Bool
    /// Monotonically increasing sequence number — guarantees insertion order when timestamps collide
    var ordinal: Int

    // Relationship to task - many messages belong to one task
    var task: ChatTask?

    init(timestamp: Date = Date(), content: String, task: ChatTask? = nil, isStreaming: Bool = false, ordinal: Int = 0) {
        self.timestamp = timestamp
        self.content = content
        self.task = task
        self.isStreaming = isStreaming
        self.ordinal = ordinal
    }
}

/// A task grouping - represents one "New Task" section
@Model
final class ChatTask {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var prompt: String
    var summary: String?
    var isCancelled: Bool
    
    @Relationship(deleteRule: .cascade)
    var messages: [ChatMessage] = []
    
    init(id: UUID = UUID(), startTime: Date = Date(), prompt: String = "") {
        self.id = id
        self.startTime = startTime
        self.prompt = prompt
        self.isCancelled = false
    }
}

/// Persisted script tab log data
@Model
final class ScriptTabRecord {
    var tabId: UUID
    var scriptName: String
    var activityLog: String
    var exitCode: Int  // -999 = nil (SwiftData doesn't support optional Int32)

    init(tabId: UUID, scriptName: String, activityLog: String, exitCode: Int = -999) {
        self.tabId = tabId
        self.scriptName = scriptName
        self.activityLog = activityLog
        self.exitCode = exitCode
    }
}

/// Manages chat history storage with SwiftData
@MainActor
final class ChatHistoryStore {
    static let shared = ChatHistoryStore()
    
    var container: ModelContainer?
    var context: ModelContext?

    private var currentTask: ChatTask?
    /// Monotonically increasing counter for message ordering within a task
    private var nextOrdinal: Int = 0
    
    private init() {
        let schema = Schema([ChatMessage.self, ChatTask.self, ScriptTabRecord.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: config)
            context = container?.mainContext
            // Test fetch to verify tables exist (catches stale schema)
            _ = try context?.fetchCount(FetchDescriptor<ChatTask>())
        } catch {
            print("SwiftData schema stale or corrupt — recreating: \(error)")
            deleteStoreFiles()
            do {
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                container = try ModelContainer(for: schema, configurations: config)
                context = container?.mainContext
            } catch {
                print("Failed to initialize SwiftData after reset: \(error)")
            }
        }
    }

    private func deleteStoreFiles() {
        container = nil
        context = nil
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let fm = FileManager.default
        // SwiftData default store files
        for suffix in ["default.store", "default.store-shm", "default.store-wal"] {
            let url = appSupport.appendingPathComponent(suffix)
            try? fm.removeItem(at: url)
        }
    }
    
    // MARK: - Task Management
    
    /// Start a new task grouping
    @discardableResult
    func startNewTask(prompt: String) -> UUID {
        let task = ChatTask(prompt: prompt)
        context?.insert(task)
        currentTask = task
        nextOrdinal = 0
        safeSave()
        return task.id
    }
    
    /// End current task with optional summary
    func endCurrentTask(summary: String? = nil, cancelled: Bool = false) {
        guard let task = currentTask, let context else {
            currentTask = nil
            return
        }
        // Guard against faulted/deleted objects that cause Core Data crashes
        if context.hasChanges {
            task.endTime = Date()
            task.summary = summary
            task.isCancelled = cancelled
        }
        do {
            try context.save()
        } catch {
            // Context in bad state — rollback to prevent cascading crashes
            context.rollback()
        }
        currentTask = nil
    }
    
    /// Get the current active task
    var activeTask: ChatTask? { currentTask }
    
    // MARK: - Message Operations
    
    /// Append a message to the current task
    func appendMessage(_ content: String, timestamp: Date = Date()) {
        guard let task = currentTask else { return }
        let message = ChatMessage(timestamp: timestamp, content: content, task: task, ordinal: nextOrdinal)
        nextOrdinal += 1
        context?.insert(message)
    }

    /// Append streaming content (LLM output)
    func appendStreamingContent(_ content: String) {
        guard let task = currentTask else { return }
        let message = ChatMessage(timestamp: Date(), content: content, task: task, isStreaming: true, ordinal: nextOrdinal)
        nextOrdinal += 1
        context?.insert(message)
    }
    
    /// Save pending changes
    func save() {
        do {
            try context?.save()
        } catch {
            context?.rollback()
        }
    }

    /// Safe save that won't propagate exceptions
    private func safeSave() {
        do {
            try context?.save()
        } catch {
            context?.rollback()
        }
    }
    
    /// Fetch recent tasks with their messages
    func fetchRecentTasks(limit: Int = 3) -> [(task: ChatTask, messages: [ChatMessage])] {
        guard let context else { return [] }
        
        let descriptor = FetchDescriptor<ChatTask>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        do {
            let tasks = try context.fetch(descriptor)
            let recent = Array(tasks.prefix(limit))
            
            return recent.compactMap { task in
                let sorted = task.messages.sorted {
                    // Primary: ordinal (monotonic insertion order)
                    // Fallback: timestamp (for legacy data where ordinal is 0)
                    if $0.ordinal != $1.ordinal { return $0.ordinal < $1.ordinal }
                    return $0.timestamp < $1.timestamp
                }
                return (task: task, messages: sorted)
            }.reversed().map { $0 } // Reverse to get chronological order
        } catch {
            return []
        }
    }
    
    // MARK: - UI Display (full messages, never summarized)

    /// Build the activity log text for the UI. Always uses full messages — never summaries.
    func buildActivityLogText(maxTasks: Int = 3) -> String {
        let tasks = fetchRecentTasks(limit: maxTasks)
        var result = ""

        for (_, messages) in tasks {
            result += "--- New Task ---\n"
            for msg in messages {
                if msg.isStreaming {
                    // Streaming fragments are partial tokens — concatenate without extra newlines
                    // (the final newline is stored as its own streaming message by flushStreamBuffer)
                    result += msg.content
                } else {
                    // Non-streaming messages (appendLog, appendRawOutput) are complete lines
                    result += msg.content
                    if !msg.content.hasSuffix("\n") {
                        result += "\n"
                    }
                }
            }
        }

        return result
    }

    // MARK: - LLM Context (uses summaries for older tasks)

    /// Build a concise context string for the LLM system prompt.
    /// Recent tasks get full messages; older tasks use their summary if available.
    func buildLLMContext(recentFullTasks: Int = 1, maxOlderSummaries: Int = 5) -> String {
        guard let context else { return "" }

        let descriptor = FetchDescriptor<ChatTask>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )

        guard let allTasks = try? context.fetch(descriptor), !allTasks.isEmpty else { return "" }

        var result = "\n\nChat history (most recent last):\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        // Older tasks: use summary only (skip those without a summary)
        let olderTasks = allTasks.dropFirst(recentFullTasks).prefix(maxOlderSummaries).reversed()
        for task in olderTasks {
            let time = formatter.string(from: task.startTime)
            if let summary = task.summary, !summary.isEmpty {
                result += "[\(time)] Task: \(task.prompt) → \(summary)\n"
            } else {
                result += "[\(time)] Task: \(task.prompt)\n"
            }
        }

        // Most recent task(s): include full messages so the LLM has detailed context
        let recentTasks = allTasks.prefix(recentFullTasks).reversed()
        for task in recentTasks {
            result += "--- Recent Task ---\n"
            result += "[\(formatter.string(from: task.startTime))] Task: \(task.prompt)\n"
            let sorted = task.messages.sorted {
                if $0.ordinal != $1.ordinal { return $0.ordinal < $1.ordinal }
                return $0.timestamp < $1.timestamp
            }
            for msg in sorted {
                if msg.isStreaming {
                    result += msg.content
                } else {
                    result += msg.content
                    if !msg.content.hasSuffix("\n") {
                        result += "\n"
                    }
                }
            }
            if let summary = task.summary {
                result += "Result: \(summary)\n"
            }
        }

        return result
    }
    
    // MARK: - Script Tab Persistence

    /// Save script tab data to SwiftData. Replaces any existing records.
    func saveScriptTabs(_ tabs: [(id: UUID, scriptName: String, activityLog: String, exitCode: Int32?)]) {
        guard let context else { return }
        // Delete old records
        try? context.delete(model: ScriptTabRecord.self)
        // Insert new
        for tab in tabs {
            let record = ScriptTabRecord(
                tabId: tab.id,
                scriptName: tab.scriptName,
                activityLog: tab.activityLog,
                exitCode: tab.exitCode.map { Int($0) } ?? -999
            )
            context.insert(record)
        }
        try? context.save()
    }

    /// Restore script tab data from SwiftData keyed by tab UUID.
    func fetchScriptTabs() -> [ScriptTabRecord] {
        guard let context else { return [] }
        do {
            return try context.fetch(FetchDescriptor<ScriptTabRecord>())
        } catch {
            return []
        }
    }

    /// Clear persisted script tab records.
    func clearScriptTabs() {
        guard let context else { return }
        try? context.delete(model: ScriptTabRecord.self)
        try? context.save()
    }

    /// Clear all history
    func clearAll() {
        guard let context else { return }
        
        do {
            try context.delete(model: ChatMessage.self)
            try context.delete(model: ChatTask.self)
            try context.save()
        } catch {
            print("Failed to clear history: \(error)")
        }
        
        currentTask = nil
    }
    
    /// Count total tasks
    func taskCount() -> Int {
        guard let context else { return 0 }
        do {
            return try context.fetchCount(FetchDescriptor<ChatTask>())
        } catch {
            return 0
        }
    }
    
    /// Count total messages
    func messageCount() -> Int {
        guard let context else { return 0 }
        do {
            return try context.fetchCount(FetchDescriptor<ChatMessage>())
        } catch {
            return 0
        }
    }
    
    /// Migrate old UserDefaults data to SwiftData (one-time)
    func migrateFromUserDefaults() {
        let key = "agentActivityLog"
        guard let saved = UserDefaults.standard.string(forKey: key),
              !saved.isEmpty else { return }
        
        // Check if we've already migrated
        if UserDefaults.standard.bool(forKey: "agentActivityLogMigrated") {
            return
        }
        
        // Don't migrate if we already have tasks in SwiftData
        if taskCount() > 0 {
            UserDefaults.standard.set(true, forKey: "agentActivityLogMigrated")
            return
        }
        
        let marker = "--- New Task ---"
        let sections = saved.components(separatedBy: marker)
        
        let timestampPattern = #"^\[(\d{2}:\d{2}:\d{2})\]\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: timestampPattern) else { return }
        
        for section in sections where !section.isEmpty {
            let lines = section.components(separatedBy: "\n")
            var taskPrompt = "Migrated task"
            
            // First non-timestamp line might be the task description
            for line in lines.prefix(3) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, !trimmed.hasPrefix("[") {
                    taskPrompt = trimmed
                    break
                }
            }
            
            let task = ChatTask(prompt: taskPrompt)
            context?.insert(task)
            
            for line in lines {
                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                
                if let match = regex.firstMatch(in: line, range: range) {
                    let timeStr = nsLine.substring(with: match.range(at: 1))
                    let content = nsLine.substring(with: match.range(at: 2))
                    
                    // Parse time and create date
                    let parts = timeStr.components(separatedBy: ":")
                    var date = Date()
                    if parts.count == 3,
                       let hour = Int(parts[0]),
                       let minute = Int(parts[1]),
                       let second = Int(parts[2]) {
                        let cal = Calendar.current
                        date = cal.date(bySettingHour: hour, minute: minute, second: second, of: Date()) ?? Date()
                    }
                    
                    let message = ChatMessage(timestamp: date, content: content, task: task)
                    context?.insert(message)
                }
            }
        }
        
        try? context?.save()
        UserDefaults.standard.set(true, forKey: "agentActivityLogMigrated")
        print("Migrated chat history to SwiftData")
    }
}
