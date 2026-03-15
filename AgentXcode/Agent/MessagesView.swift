import SwiftUI

struct MessagesView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Messages Monitor")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $viewModel.messagesMonitorEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(.green)
                Button {
                    viewModel.refreshMessageRecipients()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh recipients")
            }

            Divider()

            if viewModel.messageRecipients.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "message")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No recipients found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open Messages app and send a message first.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                HStack {
                    Text("Select recipients to monitor:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("All") {
                        viewModel.enabledChatIds = Set(viewModel.messageRecipients.map(\.chatId))
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                    Button("None") {
                        viewModel.enabledChatIds.removeAll()
                    }
                    .buttonStyle(.bordered).controlSize(.mini)
                }

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.messageRecipients) { recipient in
                            recipientRow(recipient)
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Send \"Agent! <prompt>\" from a checked recipient to trigger a task.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("If none are selected, all incoming messages are monitored.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 380, height: 600)
        .frame(minHeight: 300, maxHeight: 800)
        .onAppear {
            viewModel.refreshMessageRecipients()
        }
    }

    @ViewBuilder
    private func recipientRow(_ recipient: AgentViewModel.MessageRecipient) -> some View {
        let isEnabled = viewModel.enabledChatIds.contains(recipient.chatId)

        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { viewModel.enabledChatIds.contains(recipient.chatId) },
                set: { newValue in
                    if newValue {
                        viewModel.enabledChatIds.insert(recipient.chatId)
                    } else {
                        viewModel.enabledChatIds.remove(recipient.chatId)
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(.blue)

            VStack(alignment: .leading, spacing: 1) {
                Text(recipient.displayName)
                    .font(.subheadline)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                Text(recipient.service)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isEnabled ? Color.blue.opacity(0.05) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
