import Testing
import Foundation
@testable import Agent_

@Suite("CodingService")
struct CodingServiceTests {

    /// Temp directory for test files, cleaned up after each test via defer.
    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "agent_coding_tests_\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - readFile

    @Test("readFile returns numbered lines")
    func readFileBasic() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/hello.txt"
        try! "line1\nline2\nline3\n".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.readFile(path: file, offset: nil, limit: nil)
        #expect(result.contains("1\tline1"))
        #expect(result.contains("2\tline2"))
        #expect(result.contains("3\tline3"))
    }

    @Test("readFile with offset and limit")
    func readFileOffsetLimit() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/lines.txt"
        let content = (1...20).map { "line\($0)" }.joined(separator: "\n")
        try! content.write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.readFile(path: file, offset: 5, limit: 3)
        #expect(result.contains("line5"))
        #expect(result.contains("line6"))
        #expect(result.contains("line7"))
        #expect(!result.contains("line4"))
        #expect(!result.contains("line8"))
    }

    @Test("readFile returns error for missing file")
    func readFileMissing() {
        let result = CodingService.readFile(path: "/tmp/nonexistent_\(UUID()).txt", offset: nil, limit: nil)
        #expect(result.contains("Error: file not found"))
    }

    @Test("readFile returns error for directory")
    func readFileDirectory() {
        let result = CodingService.readFile(path: NSTemporaryDirectory(), offset: nil, limit: nil)
        #expect(result.contains("Error: path is a directory"))
    }

    @Test("readFile returns error for offset past end")
    func readFileOffsetPastEnd() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/short.txt"
        try! "one\ntwo\n".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.readFile(path: file, offset: 100, limit: nil)
        #expect(result.contains("Error: offset"))
    }

    @Test("readFile handles tilde expansion")
    func readFileTilde() {
        // ~/. always exists (home directory is a directory)
        let result = CodingService.readFile(path: "~/.", offset: nil, limit: nil)
        #expect(result.contains("Error: path is a directory"))
    }

    @Test("readFile shows truncation notice for large files")
    func readFileTruncation() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/big.txt"
        let content = (1...100).map { "line\($0)" }.joined(separator: "\n")
        try! content.write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.readFile(path: file, offset: nil, limit: 10)
        #expect(result.contains("line1"))
        #expect(result.contains("line10"))
        #expect(result.contains("more lines"))
        #expect(!result.contains("line11"))
    }

    // MARK: - writeFile

    @Test("writeFile creates a new file")
    func writeFileNew() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/new.txt"

        let result = CodingService.writeFile(path: file, content: "hello world")
        #expect(result.contains("Wrote"))
        #expect(result.contains("1 lines"))

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents == "hello world")
    }

    @Test("writeFile creates parent directories")
    func writeFileCreatesParents() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/a/b/c/deep.txt"

        let result = CodingService.writeFile(path: file, content: "deep content")
        #expect(result.contains("Wrote"))
        #expect(FileManager.default.fileExists(atPath: file))
    }

    @Test("writeFile overwrites existing file")
    func writeFileOverwrite() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/overwrite.txt"
        try! "old content".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.writeFile(path: file, content: "new content")
        #expect(result.contains("Wrote"))

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents == "new content")
    }

    @Test("writeFile reports correct line count")
    func writeFileLineCount() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/counted.txt"

        let result = CodingService.writeFile(path: file, content: "a\nb\nc\nd")
        #expect(result.contains("4 lines"))
    }

    // MARK: - editFile

    @Test("editFile replaces single occurrence")
    func editFileSingle() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/edit.txt"
        try! "Hello World".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "World", newString: "Swift", replaceAll: false)
        #expect(result.contains("Replaced 1 occurrence"))

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents == "Hello Swift")
    }

    @Test("editFile replace_all replaces all occurrences")
    func editFileReplaceAll() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/multi.txt"
        try! "foo bar foo baz foo".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "foo", newString: "qux", replaceAll: true)
        #expect(result.contains("3 occurrence(s)"))

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents == "qux bar qux baz qux")
    }

    @Test("editFile errors on ambiguous match without replace_all")
    func editFileAmbiguous() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/ambig.txt"
        try! "aaa bbb aaa".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "aaa", newString: "ccc", replaceAll: false)
        #expect(result.contains("appears 2 times"))
    }

    @Test("editFile errors when old_string not found")
    func editFileNotFound() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/nope.txt"
        try! "some content".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "missing", newString: "x", replaceAll: false)
        #expect(result.contains("Error: old_string not found"))
    }

    @Test("editFile hints about whitespace mismatch")
    func editFileWhitespaceHint() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/ws.txt"
        // File contains "hello world" but we search for "  hello world  " (with extra whitespace)
        // The trimmed search string "hello world" IS found in content, triggering the hint
        try! "hello world".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "  hello world  ", newString: "x", replaceAll: false)
        #expect(result.contains("whitespace"))
    }

    @Test("editFile errors when old and new are identical")
    func editFileIdentical() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/same.txt"
        try! "content".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(path: file, oldString: "content", newString: "content", replaceAll: false)
        #expect(result.contains("identical"))
    }

    @Test("editFile errors for missing file")
    func editFileMissingFile() {
        let result = CodingService.editFile(path: "/tmp/nonexistent_\(UUID()).txt", oldString: "a", newString: "b", replaceAll: false)
        #expect(result.contains("Error: file not found"))
    }

    @Test("editFile preserves file content around replacement")
    func editFilePreservesContext() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/context.txt"
        try! "line1\nTARGET\nline3".write(toFile: file, atomically: true, encoding: .utf8)

        _ = CodingService.editFile(path: file, oldString: "TARGET", newString: "REPLACED", replaceAll: false)

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents == "line1\nREPLACED\nline3")
    }

    @Test("editFile handles multiline old_string")
    func editFileMultiline() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/multiline.txt"
        try! "func foo() {\n    return 1\n}".write(toFile: file, atomically: true, encoding: .utf8)

        let result = CodingService.editFile(
            path: file,
            oldString: "func foo() {\n    return 1\n}",
            newString: "func foo() {\n    return 42\n}",
            replaceAll: false
        )
        #expect(result.contains("Replaced 1 occurrence"))

        let contents = try! String(contentsOfFile: file, encoding: .utf8)
        #expect(contents.contains("return 42"))
    }

    // MARK: - Shell Escape

    @Test("shellEscape wraps in single quotes")
    func shellEscapeBasic() {
        let result = CodingService.shellEscape("hello world")
        #expect(result == "'hello world'")
    }

    @Test("shellEscape handles single quotes in strings")
    func shellEscapeQuotes() {
        let result = CodingService.shellEscape("it's a test")
        #expect(result == "'it'\\''s a test'")
    }

    @Test("shellEscape handles empty string")
    func shellEscapeEmpty() {
        let result = CodingService.shellEscape("")
        #expect(result == "''")
    }

    @Test("shellEscape handles special chars")
    func shellEscapeSpecialChars() {
        let result = CodingService.shellEscape("$HOME && rm -rf /")
        // Single quotes prevent shell expansion
        #expect(result == "'$HOME && rm -rf /'")
    }

    // MARK: - Command Builders

    @Test("buildListFilesCommand includes pattern and path")
    func buildListFiles() {
        let cmd = CodingService.buildListFilesCommand(pattern: "*.swift", path: "/tmp/project")
        #expect(cmd.contains("find"))
        #expect(cmd.contains("'/tmp/project'"))
        #expect(cmd.contains("-name '*.swift'"))
        #expect(cmd.contains("-maxdepth 10"))
        #expect(cmd.contains("| sort"))
    }

    @Test("buildListFilesCommand defaults to home dir")
    func buildListFilesDefaultPath() {
        let cmd = CodingService.buildListFilesCommand(pattern: "*.txt", path: nil)
        #expect(cmd.contains(CodingService.defaultDir))
    }

    @Test("buildSearchFilesCommand includes pattern and excludes")
    func buildSearchFiles() {
        let cmd = CodingService.buildSearchFilesCommand(pattern: "TODO", path: "/tmp/project", include: "*.swift")
        #expect(cmd.contains("grep -rn"))
        #expect(cmd.contains("'TODO'"))
        #expect(cmd.contains("'/tmp/project'"))
        #expect(cmd.contains("--include='*.swift'"))
        #expect(cmd.contains("--exclude-dir=.git"))
    }

    @Test("buildSearchFilesCommand works without include")
    func buildSearchFilesNoInclude() {
        let cmd = CodingService.buildSearchFilesCommand(pattern: "error", path: "/tmp", include: nil)
        #expect(!cmd.contains("--include"))
        #expect(cmd.contains("'error'"))
    }

    @Test("buildGitStatusCommand uses cd")
    func buildGitStatus() {
        let cmd = CodingService.buildGitStatusCommand(path: "/tmp/repo")
        #expect(cmd.contains("cd '/tmp/repo'"))
        #expect(cmd.contains("git branch --show-current"))
        #expect(cmd.contains("git status --short"))
    }

    @Test("buildGitDiffCommand handles staged and target")
    func buildGitDiff() {
        let cmd = CodingService.buildGitDiffCommand(path: "/tmp/repo", staged: true, target: "main")
        #expect(cmd.contains("cd '/tmp/repo'"))
        #expect(cmd.contains("--cached"))
        #expect(cmd.contains("'main'"))
    }

    @Test("buildGitDiffCommand omits --cached when not staged")
    func buildGitDiffUnstaged() {
        let cmd = CodingService.buildGitDiffCommand(path: "/tmp/repo", staged: false, target: nil)
        #expect(!cmd.contains("--cached"))
    }

    @Test("buildGitLogCommand respects count limit")
    func buildGitLog() {
        let cmd = CodingService.buildGitLogCommand(path: "/tmp/repo", count: 5)
        #expect(cmd.contains("-5"))
    }

    @Test("buildGitLogCommand caps at 100")
    func buildGitLogMaxCap() {
        let cmd = CodingService.buildGitLogCommand(path: "/tmp/repo", count: 500)
        #expect(cmd.contains("-100"))
    }

    @Test("buildGitCommitCommand with specific files")
    func buildGitCommitFiles() {
        let cmd = CodingService.buildGitCommitCommand(path: "/tmp/repo", message: "fix bug", files: ["a.swift", "b.swift"])
        #expect(cmd.contains("git add 'a.swift' 'b.swift'"))
        #expect(cmd.contains("git commit -m 'fix bug'"))
        #expect(!cmd.contains("git add -A"))
    }

    @Test("buildGitCommitCommand with no files uses add -A")
    func buildGitCommitAll() {
        let cmd = CodingService.buildGitCommitCommand(path: "/tmp/repo", message: "update", files: nil)
        #expect(cmd.contains("git add -A"))
    }

    @Test("buildGitCommitCommand escapes single quotes in message")
    func buildGitCommitQuotedMessage() {
        let cmd = CodingService.buildGitCommitCommand(path: "/tmp/repo", message: "it's done", files: nil)
        #expect(cmd.contains("'it'\\''s done'"))
    }

    @Test("buildGitBranchCommand with checkout")
    func buildGitBranchCheckout() {
        let cmd = CodingService.buildGitBranchCommand(path: "/tmp/repo", name: "feature/new", checkout: true)
        #expect(cmd.contains("git checkout -b"))
        #expect(cmd.contains("'feature/new'"))
    }

    @Test("buildGitBranchCommand without checkout")
    func buildGitBranchNoCheckout() {
        let cmd = CodingService.buildGitBranchCommand(path: "/tmp/repo", name: "bugfix", checkout: false)
        #expect(cmd.contains("git branch 'bugfix'"))
        #expect(!cmd.contains("checkout"))
    }
}
