import Testing
import Foundation
@testable import Agent

@Suite("ScriptService")
@MainActor
struct ScriptServiceTests {
    let service = ScriptService()

    // Use a temp directory to avoid polluting real agents dir
    static let testDir: URL = {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentTests_\(UUID().uuidString)")
            .appendingPathComponent("Sources")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Create

    @Test("Create script produces Sources/{name}/main.swift")
    func createScript() {
        let result = service.createScript(name: "test_hello", content: "print(\"hello\")")
        #expect(result.contains("Created test_hello"))

        let source = service.readScript(name: "test_hello")
        #expect(source == "print(\"hello\")")

        // Cleanup
        _ = service.deleteScript(name: "test_hello")
    }

    @Test("Create script strips .swift suffix from name")
    func createScriptStripsSuffix() {
        let result = service.createScript(name: "suffix_test.swift", content: "// test")
        #expect(result.contains("Created suffix_test"))

        let source = service.readScript(name: "suffix_test")
        #expect(source == "// test")

        _ = service.deleteScript(name: "suffix_test")
    }

    @Test("Create duplicate script returns error")
    func createDuplicateScript() {
        _ = service.createScript(name: "dup_test", content: "// first")
        let result = service.createScript(name: "dup_test", content: "// second")
        #expect(result.contains("already exists"))

        _ = service.deleteScript(name: "dup_test")
    }

    // MARK: - Read

    @Test("Read nonexistent script returns nil")
    func readNonexistent() {
        let source = service.readScript(name: "does_not_exist_\(UUID().uuidString)")
        #expect(source == nil)
    }

    // MARK: - Update

    @Test("Update existing script changes content")
    func updateScript() {
        _ = service.createScript(name: "update_test", content: "// v1")
        let result = service.updateScript(name: "update_test", content: "// v2")
        #expect(result.contains("Updated update_test"))

        let source = service.readScript(name: "update_test")
        #expect(source == "// v2")

        _ = service.deleteScript(name: "update_test")
    }

    @Test("Update nonexistent script returns error")
    func updateNonexistent() {
        let result = service.updateScript(name: "no_such_script_\(UUID().uuidString)", content: "// x")
        #expect(result.contains("not found"))
    }

    // MARK: - Delete

    @Test("Delete existing script succeeds")
    func deleteScript() {
        _ = service.createScript(name: "delete_me", content: "// bye")
        let result = service.deleteScript(name: "delete_me")
        #expect(result.contains("Deleted delete_me"))

        let source = service.readScript(name: "delete_me")
        #expect(source == nil)
    }

    @Test("Delete nonexistent script returns error")
    func deleteNonexistent() {
        let result = service.deleteScript(name: "ghost_script_\(UUID().uuidString)")
        #expect(result.contains("not found"))
    }

    // MARK: - List

    @Test("List scripts includes created script")
    func listScripts() {
        _ = service.createScript(name: "list_test", content: "// listed")
        let scripts = service.listScripts()
        let names = scripts.map(\.name)
        #expect(names.contains("list_test"))

        _ = service.deleteScript(name: "list_test")
    }

    @Test("List scripts excludes ScriptingBridges")
    func listExcludesBridges() {
        let scripts = service.listScripts()
        let names = scripts.map(\.name)
        #expect(!names.contains("ScriptingBridges"))
    }

    // MARK: - Compile Command

    @Test("compileAndRunCommand returns swift build command")
    func compileCommand() {
        _ = service.createScript(name: "cmd_test", content: "print(\"hi\")")
        let cmd = service.compileAndRunCommand(name: "cmd_test")
        #expect(cmd != nil)
        #expect(cmd!.contains("swift build --product 'cmd_test'"))
        #expect(cmd!.contains(".build/debug/'cmd_test'"))

        _ = service.deleteScript(name: "cmd_test")
    }

    @Test("compileAndRunCommand returns nil for missing script")
    func compileCommandMissing() {
        let cmd = service.compileAndRunCommand(name: "no_such_\(UUID().uuidString)")
        #expect(cmd == nil)
    }

    @Test("compileAndRunCommand includes arguments")
    func compileCommandWithArgs() {
        _ = service.createScript(name: "args_test", content: "// args")
        let cmd = service.compileAndRunCommand(name: "args_test", arguments: "--verbose foo")
        #expect(cmd != nil)
        #expect(cmd!.contains("--verbose foo"))

        _ = service.deleteScript(name: "args_test")
    }
}
