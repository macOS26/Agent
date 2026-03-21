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
@MainActor
final class AppleIntelligenceMediator: ObservableObject {
    static let shared = AppleIntelligenceMediator()

    /// Timeout for Apple Intelligence calls (seconds). Prevents hanging LLM tasks.
    private static let responseTimeout: TimeInterval = 10

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

        /// Formatted output with appropriate tag
        var formatted: String {
            let tag: String
            switch target {
            case .user: tag = "[AI → User]"
            case .llm: tag = "[AI → LLM]"
            case .both: tag = "[AI → Both]"
            }
            return "\(tag) \(content)"
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

    private func ensureSession() -> LanguageModelSession {
        // Always create a fresh session to avoid stale/stuck state
        let s = LanguageModelSession(
            model: .default,
            instructions: Instructions("""
You are a helpful mediator between a user and an AI assistant (LLM). Your role is to observe conversations
and provide brief, helpful context annotations. You annotate with specific tags:
- [AI → User] for user-facing explanations
- [AI → LLM] for LLM context injection
- [AI → Both] for information relevant to both

Keep annotations concise (1-2 sentences max). Your goal is to:
1. Explain complex tool calls to users in simple terms
2. Provide helpful context to the LLM when the user's intent is unclear
3. Summarize what just happened after significant actions
4. Suggest next steps when appropriate

Be helpful but not verbose. The primary LLM is doing the actual work - you just add clarity.
""")
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
    func contextualizeUserMessage(_ message: String) async -> Annotation? {
        guard isEnabled && injectContextToLLM && Self.isAvailable else {
            mediatorLog.debug("[contextualize] Skipped: enabled=\(self.isEnabled) inject=\(self.injectContextToLLM) available=\(Self.isAvailable)")
            return nil
        }

        let session = ensureSession()
        let prompt = """
The user said: "\(message)"

If this message is ambiguous, incomplete, or could benefit from additional context, provide a brief clarification.
If the message is clear and complete, respond with just: "CLEAR"
Otherwise, provide 1 sentence of helpful context that would help an AI assistant understand the request better.

Do not include any tags - just the context or CLEAR.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "contextualize")
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "CLEAR" || trimmed.isEmpty {
                return nil
            }
            return Annotation(target: .llm, content: trimmed, timestamp: Date())
        } catch {
            mediatorLog.warning("[contextualize] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil  // Reset stale session
            return nil
        }
    }

    /// Generate a summary annotation after the LLM completes a task
    func summarizeCompletion(summary: String, commandsRun: [String]) async -> Annotation? {
        guard isEnabled && showAnnotationsToUser && Self.isAvailable else { return nil }

        // Don't summarize if there were no commands (just conversation)
        guard !commandsRun.isEmpty else { return nil }

        let session = ensureSession()
        let prompt = """
The AI assistant just completed a task. Original summary: "\(summary)"

Provide a one-line summary of what was accomplished for the user. Focus on the outcome, not the process.
If the task was simple, you can say "CLEAR" to skip the annotation.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "summarize")
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "CLEAR" || trimmed.isEmpty {
                return nil
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
An error occurred during \(toolName):
\(error.prefix(300))

Explain this error in simple terms for the user, and suggest what they might do next.
Keep it to 1-2 sentences. Do not include any tags.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "explainError")
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
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

Suggest 1-2 logical next steps the user might want to take. Be specific and actionable.
Format as a brief suggestion. If there are no obvious next steps, respond with "CLEAR".
Do not include any tags.
"""

        do {
            let content = try await respondWithTimeout(session, prompt: prompt, label: "nextSteps")
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "CLEAR" || trimmed.isEmpty {
                return nil
            }
            return Annotation(target: .user, content: "Next steps: \(trimmed)", timestamp: Date())
        } catch {
            mediatorLog.warning("[nextSteps] Apple AI failed or timed out: \(error.localizedDescription)")
            self.session = nil
            return nil
        }
    }

    /// Clear the session to start fresh (call when switching contexts)
    func resetSession() {
        mediatorLog.info("Session reset")
        session = nil
    }
}
