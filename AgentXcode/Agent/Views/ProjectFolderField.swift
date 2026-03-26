import SwiftUI
import AppKit

/// NSTextField wrapper that disables macOS system file path autocomplete.
private struct PathTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.placeholderString = placeholder
        tf.isAutomaticTextCompletionEnabled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = .systemFont(ofSize: NSFont.systemFontSize)
        tf.focusRingType = .none
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.isScrollable = true
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ tf: NSTextField, context: Context) {
        if tf.stringValue != text {
            tf.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: PathTextField
        init(_ parent: PathTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let tf = obj.object as? NSTextField else { return }
            parent.text = tf.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onSubmit()
            parent.onFocusChange(false)
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusChange(true)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                // Resign first responder to dismiss
                control.window?.makeFirstResponder(nil)
                return true
            }
            // Block system completion (F5, Escape completion)
            if commandSelector == #selector(NSResponder.complete(_:)) {
                return true
            }
            return false
        }
    }
}

/// A text field with a dropdown of recent project folders
struct ProjectFolderField: View {
    @Binding var projectFolder: String
    var onFolderSelected: (() -> Void)? = nil

    @State private var showRecentFolders = false
    @State private var isFieldFocused = false
    
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

                PathTextField(
                    text: $projectFolder,
                    placeholder: "Project folder...",
                    onSubmit: {
                        if !projectFolder.isEmpty {
                            projectFolder = Self.resolveToFolder(projectFolder)
                            RecentFoldersService.shared.addFolder(projectFolder)
                        }
                        showRecentFolders = false
                        onFolderSelected?()
                    },
                    onFocusChange: { focused in
                        if focused && !recentFolders.isEmpty {
                            showRecentFolders = true
                        } else if !focused {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if !isFieldFocused {
                                    showRecentFolders = false
                                }
                            }
                        }
                        isFieldFocused = focused
                    }
                )
                    .padding(.leading, 10)
                    .padding(.trailing, 5)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))

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
