import Foundation

/// Per-provider Retry-After backoff and min-gap throttling shared by every LLM service
/// (ClaudeService, OllamaService, OpenAICompatibleService). Previously each service kept
/// its own static dict + enforceRateLimit duplicate; this actor centralizes it so 429
/// handling, header parsing, and request gating live in one place.
///
/// Provider keys are passed as Strings (typically APIProvider.rawValue) so this file has
/// no dependency on AgentLLM and can be shared by any caller that knows a stable string id.
actor LLMRateLimiter {
    static let shared = LLMRateLimiter()

    /// Earliest absolute time the next request may fire, per provider (set by Retry-After).
    private var retryAfterUntil: [String: CFAbsoluteTime] = [:]
    /// Last request timestamp per provider, used with `minGap` for client-side throttling.
    private var lastRequestTime: [String: CFAbsoluteTime] = [:]
    /// Minimum spacing between requests per provider (seconds). Empty = no client-side gap.
    private var minGapSeconds: [String: Double] = [:]

    /// Wait if needed to respect Retry-After and the per-provider min-gap, then stamp `lastRequestTime`.
    func enforce(provider: String) async {
        let now = CFAbsoluteTimeGetCurrent()
        if let until = retryAfterUntil[provider], until > now {
            try? await Task.sleep(for: .seconds(until - now))
        }
        if let gap = minGapSeconds[provider], let last = lastRequestTime[provider] {
            let elapsed = CFAbsoluteTimeGetCurrent() - last
            if elapsed < gap {
                try? await Task.sleep(for: .seconds(gap - elapsed))
            }
        }
        lastRequestTime[provider] = CFAbsoluteTimeGetCurrent()
    }

    /// Record a Retry-After value (in seconds) seen on a 429/529 response.
    func recordRetryAfter(_ seconds: Double, provider: String) {
        retryAfterUntil[provider] = CFAbsoluteTimeGetCurrent() + seconds
    }

    /// Drop any stale 429 backoff for `provider` so a new task doesn't inherit it.
    func clearRetryAfter(provider: String) {
        retryAfterUntil.removeValue(forKey: provider)
    }

    /// Configure a minimum gap between requests for `provider`. 0 disables.
    func setMinGap(_ seconds: Double, provider: String) {
        if seconds > 0 {
            minGapSeconds[provider] = seconds
        } else {
            minGapSeconds.removeValue(forKey: provider)
        }
    }

    /// Parse Retry-After header. Integer seconds per RFC 7231 §7.1.3. Returns 0 if
    /// missing/unparseable; capped at 5 min so absurd values can't stall the app.
    nonisolated static func parseRetryAfter(_ headerValue: String?) -> Double {
        guard let v = headerValue?.trimmingCharacters(in: .whitespaces),
              !v.isEmpty,
              let seconds = Double(v) else { return 0 }
        return min(seconds, 300)
    }
}
