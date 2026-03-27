import Testing
import Foundation
@testable import Agent_
import MultiLineDiff

@Suite("DiffTools")
@MainActor struct DiffToolsTests {

    private func makeTempDir() -> String {
        let dir = NSTemporaryDirectory() + "agent_diff_tests_\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    private func writeFile(_ path: String, _ content: String) {
        try! content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func readFile(_ path: String) -> String {
        try! String(contentsOfFile: path, encoding: .utf8)
    }

    // MARK: - diff_and_apply with line ranges (truncated diff)

    @Test("diff_and_apply with start_line/end_line edits only the target section")
    func diffAndApplyLineRange() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/range_test.txt"
        // 10 line file
        let original = (1...10).map { "line \($0)" }.joined(separator: "\n") + "\n"
        writeFile(file, original)

        // Edit lines 4-6 only, send only the replacement for those lines
        let destination = "LINE 4 CHANGED\nLINE 5 CHANGED\nLINE 6 CHANGED"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 4, endLine: 6)

        #expect(!result.output.hasPrefix("Error"), "Should succeed: \(result.output)")
        #expect(result.output.contains("lines 4-6"), "Should note the line range")

        let written = readFile(file)
        // Lines 1-3 untouched
        #expect(written.contains("line 1"))
        #expect(written.contains("line 2"))
        #expect(written.contains("line 3"))
        // Lines 4-6 replaced
        #expect(written.contains("LINE 4 CHANGED"))
        #expect(written.contains("LINE 5 CHANGED"))
        #expect(written.contains("LINE 6 CHANGED"))
        // Lines 7-10 untouched
        #expect(written.contains("line 7"))
        #expect(written.contains("line 8"))
        #expect(written.contains("line 9"))
        #expect(written.contains("line 10"))
        // Original lines 4-6 gone
        #expect(!written.contains("line 4\n"))
        #expect(!written.contains("line 5\n"))
        #expect(!written.contains("line 6\n"))
    }

    @Test("diff_and_apply line range can insert more lines than it replaces")
    func diffAndApplyLineRangeInsert() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/insert_test.txt"
        let original = "A\nB\nC\nD\nE\n"
        writeFile(file, original)

        // Replace line 2 (just "B") with 3 lines
        let destination = "B1\nB2\nB3"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 2, endLine: 2)

        #expect(!result.output.hasPrefix("Error"))
        let written = readFile(file)
        #expect(written.contains("A\n"))
        #expect(written.contains("B1\nB2\nB3\n"))
        #expect(written.contains("C\n"))
    }

    @Test("diff_and_apply line range can delete lines")
    func diffAndApplyLineRangeDelete() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/delete_test.txt"
        let original = "keep1\ndelete_me\ndelete_me_too\nkeep2\n"
        writeFile(file, original)

        // Replace lines 2-3 with a single line
        let destination = "single_replacement"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 2, endLine: 3)

        #expect(!result.output.hasPrefix("Error"))
        let written = readFile(file)
        #expect(written.contains("keep1"))
        #expect(written.contains("single_replacement"))
        #expect(written.contains("keep2"))
        #expect(!written.contains("delete_me"))
    }

    @Test("diff_and_apply line range at end of file")
    func diffAndApplyLineRangeEnd() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/end_test.txt"
        let original = "first\nsecond\nthird\n"
        writeFile(file, original)

        // Edit last line
        let destination = "THIRD_CHANGED"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 3, endLine: 3)

        #expect(!result.output.hasPrefix("Error"))
        let written = readFile(file)
        #expect(written.contains("first"))
        #expect(written.contains("second"))
        #expect(written.contains("THIRD_CHANGED"))
        #expect(!written.contains("\nthird\n"))
    }

    @Test("diff_and_apply line range at start of file")
    func diffAndApplyLineRangeStart() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/start_test.txt"
        let original = "old_header\nold_import\nbody\nfooter\n"
        writeFile(file, original)

        let destination = "new_header\nnew_import\nnew_import2"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 1, endLine: 2)

        #expect(!result.output.hasPrefix("Error"))
        let written = readFile(file)
        #expect(written.hasPrefix("new_header\nnew_import\nnew_import2\n"))
        #expect(written.contains("body"))
        #expect(written.contains("footer"))
    }

    @Test("diff_and_apply shows D1F preview in display output")
    func diffAndApplyShowsPreview() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/preview_test.txt"
        let original = "aaa\nbbb\nccc\n"
        writeFile(file, original)

        let destination = "BBB_CHANGED"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 2, endLine: 2)

        #expect(!result.display.isEmpty, "Should show D1F preview")
        #expect(result.display.contains("bbb") || result.display.contains("BBB"), "Preview should reference the changed content")
    }

    // MARK: - create_diff with line ranges

    @Test("create_diff with start_line/end_line extracts section from file")
    func createDiffLineRange() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/section_test.txt"
        let original = (1...20).map { "line \($0)" }.joined(separator: "\n") + "\n"
        writeFile(file, original)

        // Read lines 5-8 from file, diff against replacement
        let fileContent = readFile(file)
        let lines = fileContent.components(separatedBy: "\n")
        let section = lines[4..<8].joined(separator: "\n") // lines 5-8 (0-indexed 4-7)
        let destination = "REPLACED 5\nREPLACED 6\nREPLACED 7\nREPLACED 8"

        let diff = MultiLineDiff.createDiff(source: section, destination: destination, includeMetadata: true, sourceStartLine: 4)
        let display = MultiLineDiff.displayDiff(diff: diff, source: section, format: .ai)

        #expect(!display.isEmpty, "Should show diff preview")
        let diffId = DiffStore.shared.store(diff: diff, source: section)
        #expect(DiffStore.shared.retrieve(diffId) != nil, "Should store for later apply")
    }

    // MARK: - Full file diff_and_apply (no line range)

    @Test("diff_and_apply without line range replaces entire file")
    func diffAndApplyFullFile() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/full_test.txt"
        writeFile(file, "old content\n")

        let destination = "completely new content\n"
        let result = CodingService.diffAndApply(path: file, source: nil, destination: destination)

        #expect(!result.output.hasPrefix("Error"))
        #expect(readFile(file) == destination)
    }

    // MARK: - Undo after diff_and_apply

    @Test("undo_edit restores original after diff_and_apply")
    func undoAfterDiffAndApply() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/undo_da_test.txt"
        let original = "line1\nline2\nline3\n"
        writeFile(file, original)

        // Record original for undo, then diff_and_apply
        DiffStore.shared.recordEdit(filePath: file, originalContent: original)
        let destination = "line1\nCHANGED\nline3\n"
        _ = CodingService.diffAndApply(path: file, source: nil, destination: destination, startLine: 2, endLine: 2)

        // Verify changed
        #expect(readFile(file).contains("CHANGED"))

        // Undo
        let undoResult = CodingService.undoEdit(path: file, originalContent: original)
        #expect(!undoResult.hasPrefix("Error"))
        #expect(readFile(file) == original, "File should be restored to original")
    }

    // MARK: - Round-trip: create_diff then apply_diff

    @Test("create_diff + apply_diff round-trip with line range")
    func createThenApplyWithLineRange() throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/roundtrip_test.txt"
        let original = "header\nimport A\nimport B\n\nfunc main() {\n    print(\"hello\")\n}\n\nfooter\n"
        writeFile(file, original)

        // Extract lines 5-7 (the function)
        let lines = original.components(separatedBy: "\n")
        let section = lines[4..<7].joined(separator: "\n")
        let newSection = "func main() {\n    print(\"goodbye\")\n    print(\"world\")\n}"

        // Create diff
        let diff = MultiLineDiff.createDiff(source: section, destination: newSection, includeMetadata: true, sourceStartLine: 4)
        let diffId = DiffStore.shared.store(diff: diff, source: section)

        // Apply diff to the section
        let stored = DiffStore.shared.retrieve(diffId)!
        let patched = try MultiLineDiff.applyDiff(to: section, diff: stored.diff)
        #expect(patched == newSection, "Patched section should match new section")
    }

    // MARK: - Edge cases

    @Test("diff_and_apply with identical content returns error")
    func diffAndApplyIdentical() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/identical_test.txt"
        writeFile(file, "same\n")

        let result = CodingService.diffAndApply(path: file, source: nil, destination: "same\n")
        #expect(result.output.contains("identical"), "Should report identical content")
    }

    @Test("diff_and_apply with nonexistent file returns error")
    func diffAndApplyMissingFile() {
        let result = CodingService.diffAndApply(path: "/tmp/nonexistent_\(UUID()).txt", source: nil, destination: "new")
        #expect(result.output.hasPrefix("Error"), "Should error on missing file")
    }

    @Test("diff_and_apply line range out of bounds clamps safely")
    func diffAndApplyOutOfBounds() {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let file = "\(dir)/bounds_test.txt"
        writeFile(file, "one\ntwo\nthree\n")

        // end_line beyond file length should clamp
        let result = CodingService.diffAndApply(path: file, source: nil, destination: "TWO\nTHREE", startLine: 2, endLine: 100)
        #expect(!result.output.hasPrefix("Error"), "Should handle gracefully")
        let written = readFile(file)
        #expect(written.contains("one"))
        #expect(written.contains("TWO"))
    }
}
