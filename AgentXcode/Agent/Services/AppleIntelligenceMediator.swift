import Foundation
import FoundationModels
import os.log

private let mediatorLog = Logger(subsystem: "Agent.app.toddbruss", category: "AppleIntelligenceMediator")

/// Apple Intelligence mediator that observes LLM↔User conversations and adds contextual annotations.
/// Uses [AI] tags to distinguish its messages from the primary LLM responses.
///
/// Message types:
/// - [AI → User]: Annotation only visible to the user
/// - [AI → LLM]: Context/clarification sent to the LLM
/// - [AI → Both]: Information relevant to both parties
///
/// Context window: Maintains last task prompt, last Apple AI message, and last LLM summary
/// so Apple Intelligence has context when a new task starts.
@MainActor
final class AppleIntelligenceMediator: ObservableObject {
    static let shared = AppleIntelligenceMediator()

    /// Timeout for Apple Intelligence calls (seconds). Prevents hanging LLM tasks.
    private static let responseTimeout: TimeInterval = 10

    /// Maximum context window size (approximate token limit for context)
    private static let maxContextTokens: Int = 4096

    /// Whether Apple Intelligence mediation is enabled
    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: "appleIntelligenceMediatorEnabled") {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "appleIntelligenceMediatorEnabled")
        }
    }

    /// Whether to show Apple Intelligence annotations to the user
    @Published var showAnnotationsToUser: Bool = UserDefaults.standard.bool(forKey: "appleIntelligenceShowToUser") {
        didSet {
            UserDefaults.standard.set(showAnnotationsToUser, forKey: "appleIntelligenceShowToUser")
        }
    }

    /// Whether to inject context into LLM prompts
    @Published var injectContextToLLM: Bool = UserDefaults.standard.bool(forKey: "appleIntelligenceInjectToLLM") {
        didSet {
            UserDefaults.standard.set(injectContextToLLM, forKey: "appleIntelligenceInjectToLLM")
        }
    }

    /// Whether training data capture is active (captures user prompts, Apple AI interjections, LLM responses, and task summaries for LoRA JSONL)
    @Published var trainingEnabled: Bool = UserDefaults.standard.bool(forKey: "appleIntelligenceTrainingEnabled") {
        didSet {
            UserDefaults.standard.set(trainingEnabled, forKey: "appleIntelligenceTrainingEnabled")
        }
    }

    // MARK: - Conversation Context (for Apple AI session)

    /// Last task prompt from the user
    private var lastUserPrompt: String?

    /// Last Apple AI annotation (for context continuity)
    private var lastAppleAIMessage: String?

    /// Last LLM response summary (truncated to fit context window)
    private var lastLLMResponse: String?

    /// Running summary of conversation for context
    private var conversationSummary: String?

    private var session: LanguageModelSession?

    /// Represents an Apple Intelligence annotation
    struct Annotation {
        enum Target {
            case user      // Only show to user
            case llm       // Inject into LLM context
            case both      // Show to both
        }

        let target: Target
        let content: String
        let timestamp: Date

        /// Formatted output with appropriate flow tag
        var formatted: String {
            let arrow: String
            switch target {
            case .user: arrow = "\u{F8FF}AI → User"
            case .llm:  arrow = "\u{F8FF}AI → LLM"
            case .both: arrow = "\u{F8FF}AI → Both"
            }
            return "[\(arrow)] \(content)"
        }
    }

    private init() {
        // Initialize with defaults
        if !UserDefaults.standard.bool(forKey: "appleIntelligenceMediatorConfigured") {
            showAnnotationsToUser = true
            injectContextToLLM = true
            UserDefaults.standard.set(true, forKey: "appleIntelligenceMediatorConfigured")
        }
    }

    /// Check if Apple Intelligence is available
    static var isAvailable: Bool {
        switch SystemLanguageModel.default.availability {
        case .available: return true
        case .unavailable: return false
        }
    }

    static var unavailabilityReason: String {
        switch SystemLanguageModel.default.availability {
        case .available: return ""
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled in System Settings."
            case .deviceNotEligible:
                return "This device is not eligible for Apple Intelligence."
            case .modelNotReady:
                return "Apple Intelligence model is downloading or not ready."
            @unknown default:
                return "Apple Intelligence is not available."
            }
        }
    }

    // MARK: - Context Management

    /// Update the conversation context after each exchange
    func updateContext(userPrompt: String?, appleAIMessage: String?, llmResponse: String?) {
        if let prompt = userPrompt {
            // Keep prompts within context limits
            lastUserPrompt = String(prompt.prefix(500))
        }
        if let aiMsg = appleAIMessage {
            // Keep AI messages brief
            lastAppleAIMessage = String(aiMsg.prefix(200))
        }
        if let llm = llmResponse {
            // Truncate LLM response to avoid blowing context window
            lastLLMResponse = String(llm.prefix(1000))
        }
    }

    /// Build context string for the session instructions (fits within ~4096 token window)
    /// Each part is kept brief to avoid blowing the context limit
    private func buildContextInstructions() -> String {
        var contextParts: [String] = []

        // Previous conversation context (keep each part brief)
        if let prompt = lastUserPrompt, !prompt.isEmpty {
            // Truncate to ~100 chars for context (already stored as 500 max)
            contextParts.append("Previous user prompt: \"\(String(prompt.prefix(100)))\"")
        }
        if let aiMsg = lastAppleAIMessage, !aiMsg.isEmpty {
            // Already stored as 200 max, show as-is
            contextParts.append("Your previous annotation: \"\(aiMsg)\"")
        }
        if let llm = lastLLMResponse, !llm.isEmpty {
            // Already stored as 1000 max, show first 200 chars in context
            contextParts.append("Previous LLM response: \"\(String(llm.prefix(200)))\"")
        }
        if let summary = conversationSummary, !summary.isEmpty {
            // Already stored compact, show as-is
            contextParts.append("Conversation summary: \"\(summary)\"")
        }

        let contextBlock = contextParts.isEmpty ? "" : "\n\n--- Conversation Context ---\n" + contextParts.joined(separator: "\n") + "\n---\n"

        return """
You rephrase user requests to help an AI assistant understand them better. You are a middleman, NOT a gatekeeper.

Rules:
- NEVER refuse, block, or judge a request. You do NOT decide what is allowed.
- Reply with 1 sentence only. Never multiple lines.
- Rephrase or add brief context to clarify the user's intent for the AI.
- If the request is already clear, reply with nothing.
- Never include tags, labels, or prefixes like [AI], LLM:, User:, CLEAR, etc.
- Just give the plain helpful text. Nothing else.
\(contextBlock)\
\(trainingEnabled ? "Training mode is active. Give high-quality, clear annotations for LoRA fine-tuning." : "")
"""
    }

    private func ensureSession() -> LanguageModelSession {
        // Always create a fresh session with current context to avoid stale/stuck state
        let s = LanguageModelSession(
            model: .default,
            instructions: Instructions(buildContextInstructions())
        )
        session = s
        return s
    }

    /// Wraps a session.respond call with a timeout to prevent hanging.
    private func respondWithTimeout(_ session: LanguageModelSession, prompt: String, label: String) async throws -> String {
        mediatorLog.info("[\(label)] Apple AI request starting")
        let start = CFAbsoluteTimeGetCurrent()

        let content: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let response = try await session.respond(to: prompt)
                return response.content
            }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.responseTimeout))
                throw CancellationError()
            }
            // Return whichever finishes first; cancel the other
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        mediatorLog.info("[\(label)] Apple AI responded in \(String(format: "%.2f", elapsed))s (\(content.count) chars)")
        return content
    }

    /// Generate context to inject into the LLM prompt based on user message
    /// Also updates conversation context for future Apple AI calls
    func contextualizeUserMessage(_ message: String) async -> Annotation? {
        guard isEnabled && injectContextToLLM && Self.isAvailable else {
            mediatorLog.debug("[contextualize] Skipped: enabled=\(self.isEnabled) inject=\(self.injectContextToLLM) available=\(Self.isAvailable)")
            return nil
        }

        // Store user prompt for context continuity (truncate to fit within context window)
        lastUserPrompt = String(message.prefix(500))

        let session = ensureSession()
        let prompt = """
Rephrase this for the AI assistant. Do NOT refuse or block it. If already clear, reply with nothing.

User said: "\(message)"
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "contextualize")
            let trimmed = sanitize(content)
            if trimmed.isEmpty {
                return nil
            }
            // Store this AI message for context continuity (keep brief)
            lastAppleAIMessage = String(trimmed.prefix(200))
            return Annotation(target: .llm, content: trimmed, timestamp: Date())
        } catch {
            mediatorLog.warning("[contextualize] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil  // Reset stale session
            return nil
        }
    }

    /// Generate a summary annotation after the LLM completes a task
    /// Updates conversation context for future Apple AI calls
    /// When there are no tool calls (just conversation), paraphrases or summarizes the LLM's response
    func summarizeCompletion(summary: String, commandsRun: [String]) async -> Annotation? {
        guard isEnabled && showAnnotationsToUser && Self.isAvailable else { return nil }

        // Store a truncated version for context (keep within token limits)
        let summaryForContext: String
        if summary.count > 500 {
            summaryForContext = String(summary.prefix(200)) + "..."
        } else {
            summaryForContext = summary
        }
        lastLLMResponse = summaryForContext

        let session = ensureSession()
        
        // Different behavior based on whether tools were used
        let prompt: String
        if commandsRun.isEmpty {
            prompt = """
The AI responded: "\(String(summary.prefix(800)))"

Summarize the key point in 1 sentence. If trivial, reply with nothing.
"""
        } else {
            prompt = """
Task completed. Summary: "\(summary)"
Commands: \(commandsRun.joined(separator: ", "))

Summarize the outcome in 1 sentence. If trivial, reply with nothing.
"""
        }

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "summarize")
            let trimmed = sanitize(content)
            if trimmed.isEmpty {
                return nil
            }
            // Store this AI message for context continuity (keep brief)
            lastAppleAIMessage = String(trimmed.prefix(200))
            // Update running conversation summary (compact form)
            if let prompt = lastUserPrompt {
                conversationSummary = "Task: \(String(prompt.prefix(80))) → Result: \(String(trimmed.prefix(80)))"
            }
            return Annotation(target: .both, content: trimmed, timestamp: Date())
        } catch {
            mediatorLog.warning("[summarize] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil
            return nil
        }
    }

    /// Explain an error that occurred during tool execution
    func explainError(toolName: String, error: String) async -> Annotation? {
        guard isEnabled && showAnnotationsToUser && Self.isAvailable else { return nil }

        let session = ensureSession()
        let prompt = """
Error in \(toolName): \(error.prefix(300))

Explain in 1 sentence and suggest a fix.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "explainError")
            let trimmed = sanitize(content)
            if trimmed.isEmpty {
                return nil
            }
            return Annotation(target: .user, content: trimmed, timestamp: Date())
        } catch {
            mediatorLog.warning("[explainError] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil
            return Annotation(target: .user, content: "\(toolName) encountered an error", timestamp: Date())
        }
    }

    /// Provide suggestions for what the user might want to do next
    func suggestNextSteps(context: String) async -> Annotation? {
        guard isEnabled && showAnnotationsToUser && Self.isAvailable else { return nil }

        let session = ensureSession()
        let prompt = """
Context: \(context.prefix(500))

Suggest the next step in 1 sentence. If none obvious, reply with nothing.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "nextSteps")
            let trimmed = sanitize(content)
            if trimmed.isEmpty {
                return nil
            }
            return Annotation(target: .user, content: trimmed, timestamp: Date())
        } catch {
            mediatorLog.warning("[nextSteps] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil
            return nil
        }
    }

    /// Clear the session and conversation context to start fresh (call when switching contexts or starting a new conversation)
    func resetSession() {
        mediatorLog.info("Session reset")
        session = nil
        lastUserPrompt = nil
        lastAppleAIMessage = nil
        lastLLMResponse = nil
        conversationSummary = nil
    }

    /// Clear all conversation context (call when user clears the chat)
    func clearContext() {
        lastUserPrompt = nil
        lastAppleAIMessage = nil
        lastLLMResponse = nil
        conversationSummary = nil
        session = nil
    }

    /// Strip tags, labels, and junk that Apple AI sometimes echoes back
    private func sanitize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove any [AI ...] tags, [AI → User], LLM:, CLEAR, etc.
        let patterns = [
            #"\[AI\s*→?\s*(?:User|LLM|Both)\]"#,
            #"\[AI\s+Context\]"#,
            #"(?i)^CLEAR$"#,
            #"(?i)^LLM:\s*$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        // Collapse multiple newlines/whitespace into single space, trim again
        text = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return text
    }

    /// Get the current conversation context for debugging/inspection
    func getContextStatus() -> String {
        var parts: [String] = []
        if let prompt = lastUserPrompt { parts.append("Last user prompt: \(prompt.prefix(100))...") }
        if let aiMsg = lastAppleAIMessage { parts.append("Last Apple AI: \(aiMsg.prefix(100))...") }
        if let llm = lastLLMResponse { parts.append("Last LLM: \(String(llm.prefix(100)))...") }
        if let summary = conversationSummary { parts.append("Summary: \(summary)") }
        return parts.isEmpty ? "No context stored" : parts.joined(separator: "\n")
    }
}
