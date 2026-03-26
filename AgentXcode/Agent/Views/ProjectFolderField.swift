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
    
    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder"
        if panel.runModal() == .OK, let url = panel.url {
            projectFolder = Self.resolveToFolder(url.path)
            RecentFoldersService.shared.addFolder(projectFolder)
            onFolderSelected?()
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    browseForFolder()
                } label: {
                    Label("Browse...", systemImage: "folder.badge.plus")
                }

                if !recentFolders.isEmpty {
                    Divider()

                    ForEach(recentFolders, id: \.self) { folder in
                        Button {
                            projectFolder = folder
                            RecentFoldersService.shared.addFolder(folder)
                            onFolderSelected?()
                        } label: {
                            Label {
                                Text((folder as NSString).lastPathComponent)
                            } icon: {
                                Image(systemName: folder == projectFolder ? "folder.fill" : "folder")
                            }
                        }
                    }
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
