import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("LoRA Training Tools")
                    .font(.headline)

                Divider()

                // Mediator Section
                mediatorSection

                Divider()

                // LoRA Sections
                LoRASettingsView()
            }
            .padding(20)
        }
        .frame(width: 380)
        .frame(maxHeight: 680)
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
                Text(AppleIntelligenceMediator.isAvailable ? "Available for conversation mediation" : "Not Available")
                    .font(.caption)
                    .foregroundStyle(AppleIntelligenceMediator.isAvailable ? .green : .secondary)
            }

            if !AppleIntelligenceMediator.isAvailable {
                Text(AppleIntelligenceMediator.unavailabilityReason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $aiMediator.isEnabled) {
                VStack(alignment: .leading) {
                    Text("Enable Mediator")
                        .font(.caption)
                    Text("Observes conversations and adds context")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if aiMediator.isEnabled {
                Toggle(isOn: $aiMediator.showAnnotationsToUser) {
                    VStack(alignment: .leading) {
                        Text("Show annotations to user")
                            .font(.caption)
                        Text("Display [\u{F8FF}AI] tags in activity log")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $aiMediator.injectContextToLLM) {
                    VStack(alignment: .leading) {
                        Text("Inject context into LLM prompts")
                            .font(.caption)
                        Text("Enriches LLM requests with AI insights")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $aiMediator.trainingEnabled) {
                    VStack(alignment: .leading) {
                        Text("Capture training data")
                            .font(.caption)
                        Text("Records prompts, AI context, LLM responses, and summaries for LoRA JSONL")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
}
