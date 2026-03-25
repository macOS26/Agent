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
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a project folder"
                    if panel.runModal() == .OK, let url = panel.url {
                        projectFolder = Self.resolveToFolder(url.path)
                        RecentFoldersService.shared.addFolder(url.path)
                        onFolderSelected?()
                    }
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 36)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                .controlSize(.regular)
                .help("Pick project folder")

                TextField("Project folder...", text: $projectFolder)
                    .textContentType(.none)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                    .focusEffectDisabled()
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        if !projectFolder.isEmpty {
                            projectFolder = Self.resolveToFolder(projectFolder)
                            RecentFoldersService.shared.addFolder(projectFolder)
                        }
                        showRecentFolders = false
                        onFolderSelected?()
                    }
                    .onChange(of: projectFolder) { oldValue, newValue in
                        // Show popup while editing if there are recent folders
                        if isTextFieldFocused && !recentFolders.isEmpty {
                            showRecentFolders = true
                        }
                    }
                    .onChange(of: isTextFieldFocused) { _, focused in
                        if focused && !recentFolders.isEmpty {
                            showRecentFolders = true
                        } else if !focused {
                            // Delay dismiss so button click can register
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if !isTextFieldFocused {
                                    showRecentFolders = false
                                }
                            }
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
                .controlSize(.regular)
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

    /// If the path points to a file (not a directory), return its parent folder.
    /// .app bundles are treated as files — returns their containing folder.
    static func resolveToFolder(_ path: String) -> String {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if exists && !isDir.boolValue {
            return (path as NSString).deletingLastPathComponent
        }
        // .app bundles report as directories but are packages — use parent
        if path.hasSuffix(".app") {
            return (path as NSString).deletingLastPathComponent
        }
        return path
    }
}
