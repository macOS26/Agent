import SwiftUI
import AppKit

/// NSTextField subclass that notifies on focus (click/tab into field).
private class FocusAwareTextField: NSTextField {
    var onFocus: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocus?() }
        return result
    }
}

/// NSTextField wrapper that disables macOS system file path autocomplete.
private struct PathTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> FocusAwareTextField {
        let tf = FocusAwareTextField()
        tf.placeholderString = placeholder
        tf.isAutomaticTextCompletionEnabled = false
        tf.isBordered = false
        tf.drawsBackground = false
        tf.font = .systemFont(ofSize: NSFont.systemFontSize)
        tf.focusRingType = .none
        tf.lineBreakMode = .byTruncatingTail
        tf.cell?.isScrollable = true
        tf.delegate = context.coordinator
        tf.onFocus = { onFocusChange(true) }
        return tf
    }

    func updateNSView(_ tf: FocusAwareTextField, context: Context) {
        if tf.stringValue != text {
            tf.stringValue = text
        }
        tf.onFocus = { onFocusChange(true) }
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

    @State private var showTree = false
    @State private var showRecentFolders = false
    @State private var isFieldFocused = false

    private var recentFolders: [String] {
        RecentFoldersService.shared.recentFolders
    }

    private func selectFolder(_ path: String) {
        projectFolder = path
        RecentFoldersService.shared.addFolder(path)
        showTree = false
        onFolderSelected?()
    }

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 8) {
            Button { showTree.toggle() } label: {
                HStack(spacing: 2) {
                    Image(systemName: "folder")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .frame(width: 36)
            }
            .buttonStyle(.bordered)
            .clipShape(Capsule())
            .controlSize(.regular)
            .help("Pick project folder")
            .popover(isPresented: $showTree) {
                FolderTreePopover(
                    selectedFolder: projectFolder,
                    onSelect: selectFolder
                )
            }

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

        // Recent folders dropdown (shows when text field is focused)
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
            .padding(.horizontal, 12)
        }

        } // VStack
        .onAppear {
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

// MARK: - Tree Popover

/// Popover with expandable directory tree from Home.
private struct FolderTreePopover: View {
    let selectedFolder: String
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                FolderTreeRow(path: home, name: "Home", depth: 0, selectedFolder: selectedFolder, onSelect: onSelect)
            }
            .padding(6)
        }
        .frame(width: 280, height: 600)
    }
}

/// A single row in the folder tree. Loads children lazily on expand.
private struct FolderTreeRow: View {
    let path: String
    let name: String
    let depth: Int
    let selectedFolder: String
    let onSelect: (String) -> Void

    @State private var isExpanded = false
    @State private var children: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                // Indent
                Spacer().frame(width: CGFloat(depth) * 16)

                // Disclosure arrow
                Button {
                    if isExpanded {
                        isExpanded = false
                    } else {
                        if children == nil {
                            children = loadChildren()
                        }
                        isExpanded = true
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)

                // Folder icon + name (click to select)
                Button {
                    onSelect(path)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: path == selectedFolder ? "folder.fill" : "folder")
                            .foregroundStyle(path == selectedFolder ? .green : .blue)
                            .frame(width: 16)
                        Text(name)
                            .lineLimit(1)
                            .foregroundStyle(path == selectedFolder ? .primary : .primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(path == selectedFolder ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(4)

            // Children (only rendered when expanded)
            if isExpanded, let children {
                ForEach(children, id: \.self) { child in
                    FolderTreeRow(
                        path: child,
                        name: (child as NSString).lastPathComponent,
                        depth: depth + 1,
                        selectedFolder: selectedFolder,
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    private func loadChildren() -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return items
            .filter { !$0.hasPrefix(".") && !$0.hasSuffix(".app") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .compactMap { name -> String? in
                let full = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { return nil }
                return full
            }
    }
}
