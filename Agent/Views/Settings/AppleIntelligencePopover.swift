import AgentAccess
import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared
    @State private var hasAccessibility = AccessibilityService.hasAccessibilityPermission()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            mediatorSection
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            hasAccessibility = AccessibilityService.hasAccessibilityPermission()
        }
    }

    // MARK: - Mediator Section

    private var mediatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple Intelligence Mediator")
                .font(.headline)

            HStack(spacing: 6) {
                Circle()
                    .fill(AppleIntelligenceMediator.isAvailable ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(AppleIntelligenceMediator.isAvailable ? "Available" : "Not Available")
                    .font(.caption)
                    .foregroundStyle(AppleIntelligenceMediator.isAvailable ? .green : .secondary)
            }

            if !AppleIntelligenceMediator.isAvailable {
                Text(AppleIntelligenceMediator.unavailabilityReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    VStack(alignment: .leading) {
                        Text("Enable Mediator")
                            .font(.caption)
                        Text("Master switch for on-device Apple AI — sub-features below are only active when this is on")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("", isOn: $aiMediator.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                        .tint(aiMediator.isEnabled ? Color.blue : Color.gray)
                }

                if aiMediator.isEnabled {
                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Triage greetings")
                                .font(.caption)
                            Text("Answer hi / hello / thanks on-device before the cloud LLM — skip the round-trip for small talk")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.triageEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .tint(aiMediator.triageEnabled ? Color.green : Color.orange)
                    }

                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Show annotations to user")
                                .font(.caption)
                            Text("Display task summaries and error explanations in the activity log")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.showAnnotationsToUser)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .tint(aiMediator.showAnnotationsToUser ? Color.pink : Color.orange)
                    }

                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Token compression")
                                .font(.caption)
                            Text("Tier 1 of context compaction — Apple AI summarizes old messages on-device when context exceeds 30K tokens. Free, private, no API tokens consumed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.tokenCompressionEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .tint(aiMediator.tokenCompressionEnabled ? Color.purple : Color.orange)
                    }

                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Accessibility intent parsing")
                                .font(.caption)
                                .foregroundStyle(hasAccessibility ? .primary : .secondary)
                            Text(hasAccessibility
                                ? "Parse \"click the Save button in TextEdit\" locally and dispatch directly to the accessibility tool — skips the cloud LLM round-trip"
                                : "Requires Accessibility permission (System Settings › Privacy & Security › Accessibility)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: Binding(
                            get: { hasAccessibility && aiMediator.accessibilityIntentEnabled },
                            set: { aiMediator.accessibilityIntentEnabled = $0 }
                        ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                            .tint(hasAccessibility && aiMediator.accessibilityIntentEnabled ? Color(red: 0.0, green: 0.2, blue: 0.7) : Color.gray)
                            .disabled(!hasAccessibility)
                    }
                }
            }
        }
    }
}
