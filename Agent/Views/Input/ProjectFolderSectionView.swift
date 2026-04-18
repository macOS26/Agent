import SwiftUI

/// Per-tab row. Must be its own View with `@Bindable var tab` so SwiftUI's
/// Observation framework tracks `tab.projectFolder` and re-renders when a
/// tool (e.g. `cd`) mutates it. When the Binding's get/set closures are
/// inlined in the parent view's body, the property access happens outside
/// observation tracking and the address bar stays stale.
private struct TabProjectFolderRow: View {
    @Bindable var viewModel: AgentViewModel
    @Bindable var tab: ScriptTab

    var body: some View {
        HStack(spacing: 4) {
            ProjectFolderField(
                projectFolder: Binding(
                    get: { tab.projectFolder.isEmpty ? viewModel.projectFolder : tab.projectFolder },
                    set: { tab.projectFolder = $0; viewModel.persistScriptTabs() }
                )
            )
            TokenBadge(
                taskIn: viewModel.taskInputTokens,
                taskOut: viewModel.taskOutputTokens,
                sessionIn: viewModel.sessionInputTokens,
                sessionOut: viewModel.sessionOutputTokens,
                providerName: viewModel.selectedProvider.displayName,
                modelName: viewModel.globalModelForProvider(viewModel.selectedProvider),
                budgetUsedFraction: viewModel.budgetUsedFraction
            )
        }
    }
}

/// Project folder section with token badge - displayed below header
struct ProjectFolderSectionView: View {
    @Bindable var viewModel: AgentViewModel
    var selectedTab: ScriptTab?

    var body: some View {
        if let tab = selectedTab {
            TabProjectFolderRow(viewModel: viewModel, tab: tab)
                .id(tab.id)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        } else {
            // Project folder/file (main tab)
            HStack(spacing: 4) {
                ProjectFolderField(projectFolder: $viewModel.projectFolder)
                TokenBadge(
                    taskIn: viewModel.taskInputTokens,
                    taskOut: viewModel.taskOutputTokens,
                    sessionIn: viewModel.sessionInputTokens,
                    sessionOut: viewModel.sessionOutputTokens,
                    providerName: viewModel.selectedProvider.displayName,
                    modelName: viewModel.globalModelForProvider(viewModel.selectedProvider),
                    budgetUsedFraction: viewModel.budgetUsedFraction
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
