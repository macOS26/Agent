import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mediatorSection
                Divider().padding(.vertical, 12)
                LoRASettingsView()
            }
            .padding(20)
        }
        .frame(width: 360)
        .frame(maxHeight: 615)
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

            }

            Text("Apple Intelligence observes conversations and adds helpful context using [\u{F8FF}AI] tags.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

}
