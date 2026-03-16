import SwiftUI

struct TabBarView: View {
    @Bindable var viewModel: AgentViewModel
    @State private var draggingTabId: UUID?
    @State private var dragOffset: CGFloat = 0

    private let swapThreshold: CGFloat = 60

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 1) {
                // Main tab (always present, not closable, not draggable)
                TabItem(
                    title: "Main",
                    isSelected: viewModel.selectedTabId == nil,
                    isRunning: viewModel.isRunning,
                    onSelect: { viewModel.selectMainTab() },
                    onClose: nil
                )

                ForEach(viewModel.scriptTabs) { tab in
                    let onSelect = { viewModel.selectedTabId = tab.id }
                    TabItem(
                        title: tab.scriptName,
                        isSelected: viewModel.selectedTabId == tab.id,
                        isRunning: tab.isRunning,
                        onSelect: onSelect,
                        onClose: { viewModel.closeScriptTab(id: tab.id) }
                    )
                    .zIndex(draggingTabId == tab.id ? 1 : 0)
                    .offset(x: draggingTabId == tab.id ? dragOffset : 0)
                    .scaleEffect(draggingTabId == tab.id ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: draggingTabId)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Only start drag after a real movement threshold
                                let dist = abs(value.translation.width)
                                if draggingTabId == nil {
                                    if dist < 5 { return } // not a drag yet
                                    draggingTabId = tab.id
                                }
                                dragOffset = value.translation.width

                                guard let fromIndex = viewModel.scriptTabs.firstIndex(where: { $0.id == tab.id }) else { return }

                                if dragOffset > swapThreshold, fromIndex < viewModel.scriptTabs.count - 1 {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.scriptTabs.swapAt(fromIndex, fromIndex + 1)
                                    }
                                    dragOffset -= swapThreshold
                                } else if dragOffset < -swapThreshold, fromIndex > 0 {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.scriptTabs.swapAt(fromIndex, fromIndex - 1)
                                    }
                                    dragOffset += swapThreshold
                                }
                            }
                            .onEnded { value in
                                if draggingTabId == nil {
                                    // Never exceeded 5pt — treat as a tap
                                    onSelect()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        dragOffset = 0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        draggingTabId = nil
                                    }
                                }
                            }
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
        .onHover { isHovering = $0 }
    }
}
