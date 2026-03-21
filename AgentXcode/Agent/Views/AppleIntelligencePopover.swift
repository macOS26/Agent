import SwiftUI

struct AppleIntelligencePopover: View {
    @ObservedObject private var aiMediator = AppleIntelligenceMediator.shared
    @Environment(\.dismiss) private var dismiss

    let bgColor = Color(red: 0.08, green: 0.08, blue: 0.12)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.cyan)
                    Text("LoRA Training Tools")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.gray.opacity(0.3))

                // Mediator Section
                mediatorSection

                Divider().background(Color.gray.opacity(0.3))

                // LoRA Sections
                LoRASettingsView()
            }
            .padding(16)
        }
        .frame(width: 420)
        .frame(maxHeight: 720)
        .background(bgColor)
    }

    // MARK: - Mediator Section

    private var mediatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Apple Intelligence Mediator")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 6) {
                Circle()
                    .fill(AppleIntelligenceMediator.isAvailable ? Color.green : Color.red.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(AppleIntelligenceMediator.isAvailable ? "Available for conversation mediation" : "Not Available")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppleIntelligenceMediator.isAvailable ? .green : .gray)
            }

            if !AppleIntelligenceMediator.isAvailable {
                Text(AppleIntelligenceMediator.unavailabilityReason)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.7))
            }

            Toggle(isOn: $aiMediator.isEnabled) {
                VStack(alignment: .leading) {
                    Text("Enable Mediator")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Observes conversations and adds context")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .toggleStyle(.switch)

            if aiMediator.isEnabled {
                Toggle(isOn: $aiMediator.showAnnotationsToUser) {
                    VStack(alignment: .leading) {
                        Text("Show annotations to user")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Display [\u{F8FF}AI] tags in activity log")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $aiMediator.injectContextToLLM) {
                    VStack(alignment: .leading) {
                        Text("Inject context into LLM prompts")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Enriches LLM requests with AI insights")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }
}
