import SwiftUI

struct TabBarView: View {
    @Bindable var viewModel: AgentViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                // Main tab (always present, not closable)
                TabItem(
                    title: "Main",
                    isSelected: viewModel.selectedTabId == nil,
                    isRunning: viewModel.isRunning,
                    onSelect: { viewModel.selectMainTab() },
                    onClose: nil
                )

                ForEach(viewModel.scriptTabs) { tab in
                    TabItem(
                        title: tab.scriptName,
                        isSelected: viewModel.selectedTabId == tab.id,
                        isRunning: tab.isRunning,
                        onSelect: { viewModel.selectedTabId = tab.id },
                        onClose: { viewModel.closeScriptTab(id: tab.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabItem: View {
    let title: String
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onClose: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if isRunning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.6)
            }
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isSelected ? 1 : 0)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.15)
                      : isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}
