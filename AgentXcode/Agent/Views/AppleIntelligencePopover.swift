import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mediatorSection
                Divider().padding(.vertical, 10)
                loraHeaderSection
                LoRASettingsView()
            }
            .padding(20)
        }
        .frame(width: 360)
        .frame(maxHeight: 600)
    }

    // MARK: - Mediator Section

    private var mediatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Apple Intelligence Mediator")
                .font(.headline)

            HStack(spacing: 6) {
                Image(systemName: AppleIntelligenceMediator.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(AppleIntelligenceMediator.isAvailable ? .green : .red)
                Text(AppleIntelligenceMediator.isAvailable ? "Available for conversation mediation" : "Not Available")
                    .font(.subheadline)
            }

            if !AppleIntelligenceMediator.isAvailable {
                Text(AppleIntelligenceMediator.unavailabilityReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Enable Apple Intelligence Mediator", isOn: $aiMediator.isEnabled)
                .font(.subheadline)

            if aiMediator.isEnabled {
                Toggle("Show annotations to user", isOn: $aiMediator.showAnnotationsToUser)
                    .font(.caption)
                Toggle("Inject context into LLM prompts", isOn: $aiMediator.injectContextToLLM)
                    .font(.caption)
                Toggle("Explain tool calls", isOn: $aiMediator.explainToolCalls)
                    .font(.caption)
            }

            Text("Apple Intelligence observes conversations and adds helpful context using [\u{F8FF}AI] tags.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - LoRA Header

    private var loraHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LoRA Training (Apple Intelligence)")
                .font(.headline)

            HStack(spacing: 6) {
                Image(systemName: FoundationModelService.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(FoundationModelService.isAvailable ? .green : .red)
                Text(FoundationModelService.isAvailable ? "Apple Intelligence Available" : "Not Available")
                    .font(.subheadline)
            }

            if !FoundationModelService.isAvailable {
                Text(FoundationModelService.unavailabilityReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(LoRAAdapterManager.shared.isLoaded ? .green : .gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(LoRAAdapterManager.shared.isLoaded ? "LoRA: \(LoRAAdapterManager.shared.adapterName)" : "No LoRA adapter loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Train custom LoRA adapters and install them as .fmadapter files for Apple Intelligence.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
