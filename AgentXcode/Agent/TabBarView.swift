import SwiftUI

struct TabBarView: View {
    @Bindable var viewModel: AgentViewModel
    @State private var draggingTabId: UUID?

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
                .onDrop(of: [.text], delegate: TabDropDelegate(
                    targetId: nil,
                    tabs: $viewModel.scriptTabs,
                    draggingId: $draggingTabId
                ))

                ForEach(viewModel.scriptTabs) { tab in
                    TabItem(
                        title: tab.scriptName,
                        isSelected: viewModel.selectedTabId == tab.id,
                        isRunning: tab.isRunning,
                        onSelect: { viewModel.selectedTabId = tab.id },
                        onClose: { viewModel.closeScriptTab(id: tab.id) }
                    )
                    .opacity(draggingTabId == tab.id ? 0.4 : 1)
                    .onDrag {
                        draggingTabId = tab.id
                        return NSItemProvider(object: tab.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        targetId: tab.id,
                        tabs: $viewModel.scriptTabs,
                        draggingId: $draggingTabId
                    ))
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct TabDropDelegate: DropDelegate {
    let targetId: UUID?          // nil = Main tab (insert at front)
    @Binding var tabs: [ScriptTab]
    @Binding var draggingId: UUID?

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingId,
              dragging != targetId,
              let fromIndex = tabs.firstIndex(where: { $0.id == dragging }) else { return }

        let toIndex: Int
        if let targetId, let idx = tabs.firstIndex(where: { $0.id == targetId }) {
            toIndex = idx
        } else {
            toIndex = 0  // dropping onto Main → move to front
        }

        guard fromIndex != toIndex else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
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
