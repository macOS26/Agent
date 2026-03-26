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

    private var recentFolders: [String] {
        RecentFoldersService.shared.recentFolders
    }

    @State private var showBrowser = false
    @State private var browserPath = FileManager.default.homeDirectoryForCurrentUser.path

    /// List subdirectories of a given path, sorted alphabetically. Folders only.
    static func subdirs(of path: String) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return items
            .filter { !$0.hasPrefix(".") && !$0.hasSuffix(".app") }
            .sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
            .compactMap { name -> String? in
                let full = (path as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { return nil }
                return full
            }
    }

    private func selectFolder(_ path: String) {
        projectFolder = path
        RecentFoldersService.shared.addFolder(path)
        showBrowser = false
        onFolderSelected?()
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                // Start browser at current project folder or home
                if !projectFolder.isEmpty {
                    browserPath = projectFolder
                } else {
                    browserPath = FileManager.default.homeDirectoryForCurrentUser.path
                }
                showBrowser.toggle()
            } label: {
                Image(systemName: "folder")
                    .frame(width: 36)
            }
            .buttonStyle(.bordered)
            .clipShape(Capsule())
            .controlSize(.regular)
            .help("Pick project folder")
            .popover(isPresented: $showBrowser) {
                FolderBrowserView(
                    currentPath: $browserPath,
                    recentFolders: recentFolders,
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
                    onFolderSelected?()
                },
                onFocusChange: { _ in }
            )
                .padding(.leading, 10)
                .padding(.trailing, 5)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))

            Button {
                projectFolder = ""
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

/// Flat folder browser — shows one directory level at a time. Click to drill in, back button to go up.
private struct FolderBrowserView: View {
    @Binding var currentPath: String
    let recentFolders: [String]
    let selectedFolder: String
    let onSelect: (String) -> Void

    @State private var children: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: back button + current folder name + select button
            HStack {
                Button {
                    currentPath = (currentPath as NSString).deletingLastPathComponent
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPath == "/")
                .buttonStyle(.borderless)

                Text((currentPath as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.head)

                Spacer()

                Button("Select") {
                    onSelect(currentPath)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            // Recent folders section
            if !recentFolders.isEmpty {
                Text("Recent")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                ForEach(recentFolders.prefix(6), id: \.self) { folder in
                    Button {
                        onSelect(folder)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: folder == selectedFolder ? "folder.fill" : "folder")
                                .foregroundStyle(.blue)
                                .frame(width: 16)
                            Text((folder as NSString).lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.vertical, 4)
            }

            // Directory listing
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(children, id: \.self) { child in
                        Button {
                            currentPath = child
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.blue)
                                    .frame(width: 16)
                                Text((child as NSString).lastPathComponent)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 260, height: 340)
        .onAppear { children = ProjectFolderField.subdirs(of: currentPath) }
        .onChange(of: currentPath) { children = ProjectFolderField.subdirs(of: currentPath) }
    }
}
