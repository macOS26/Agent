import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Text("LoRA Training Tools")
                    .font(.headline)
                
                Text("Train and manage LoRA adapters for local models.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                // Mediator Section
                mediatorSection

                Divider()

                // LoRA Sections
                LoRASettingsView()
            }
            .padding(20)
            .padding(.bottom, 15)
        }
        .frame(width: 380)
        .frame(maxHeight: 700)
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
                        Text("Rephrases and clarifies user requests for the LLM")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("", isOn: $aiMediator.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }

                if aiMediator.isEnabled {
                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Show annotations to user")
                                .font(.caption)
                            Text("Display [\u{F8FF}AI → ...] flow tags in activity log")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.showAnnotationsToUser)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }

                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Inject context into LLM prompts")
                                .font(.caption)
                            Text("Adds rephrased context to LLM prompts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.injectContextToLLM)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }

                    GridRow {
                        VStack(alignment: .leading) {
                            Text("Capture training data")
                                .font(.caption)
                            Text("Records prompts, AI context, LLM responses, and summaries for LoRA JSONL")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("", isOn: $aiMediator.trainingEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                }
            }
        }
    }
}
