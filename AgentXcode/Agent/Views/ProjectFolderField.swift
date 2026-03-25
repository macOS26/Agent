import SwiftUI

/// A text field with a dropdown of recent project folders
struct ProjectFolderField: View {
    @Binding var projectFolder: String
    var onFolderSelected: (() -> Void)? = nil
    
    @State private var showRecentFolders = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var recentFolders: [String] {
        RecentFoldersService.shared.recentFolders
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a project folder or file"
                    if panel.runModal() == .OK, let url = panel.url {
                        projectFolder = url.path
                        RecentFoldersService.shared.addFolder(url.path)
                        onFolderSelected?()
                    }
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 36)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help("Pick project folder or file")

                TextField("Project folder or file...", text: $projectFolder)
                    .textContentType(.none)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focusEffectDisabled()
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !projectFolder.isEmpty {
                            RecentFoldersService.shared.addFolder(projectFolder)
                        }
                        showRecentFolders = false
                        onFolderSelected?()
                    }
                    .onChange(of: projectFolder) { oldValue, newValue in
                        // Auto-add when user types a path and hits enter or focus leaves
                    }
                    .onTapGesture {
                        if !recentFolders.isEmpty {
                            showRecentFolders = true
                        }
                    }

                Button {
                    projectFolder = ""
                    showRecentFolders = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.small)
                .help("Clear project folder")
                .disabled(projectFolder.isEmpty)
            }
            
            // Recent folders dropdown
            if showRecentFolders && !recentFolders.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(recentFolders, id: \.self) { folder in
                            Button {
                                projectFolder = folder
                                RecentFoldersService.shared.addFolder(folder)
                                showRecentFolders = false
                                onFolderSelected?()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                        .frame(width: 16)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text((folder as NSString).lastPathComponent)
                                            .font(.system(size: 11, weight: .medium))
                                            .lineLimit(1)
                                        
                                        Text(folder)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(folder == projectFolder ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: min(CGFloat(recentFolders.count) * 44, 200))
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)
                .shadow(radius: 2)
                .padding(.top, 4)
            }
        }
        .onAppear {
            // Add current folder to recents if it exists
            if !projectFolder.isEmpty {
                RecentFoldersService.shared.addFolder(projectFolder)
            }
        }
    }
}