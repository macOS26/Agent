import Testing
import Foundation
@testable import Agent_

@Suite("ScriptService")
@MainActor
struct ScriptServiceTests {
    let service = ScriptService()

    // MARK: - Create

    @Test("Create script produces Sources/Scripts/{name}.swift")
    func createScript() {
        let result = service.createScript(name: "test_hello", content: "print(\"hello\")")
        #expect(result.contains("Created test_hello"))

        let source = service.readScript(name: "test_hello")
        #expect(source == "print(\"hello\")")

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

    // MARK: - Compile Command

    @Test("compileCommand returns swift build command")
    func compileCommand() {
        _ = service.createScript(name: "cmd_test", content: "print(\"hi\")")
        let cmd = service.compileCommand(name: "cmd_test")
        #expect(cmd != nil)
        #expect(cmd!.contains("swift build --product 'cmd_test'"))

        _ = service.deleteScript(name: "cmd_test")
    }

    @Test("compileCommand returns nil for missing script")
    func compileCommandMissing() {
        let cmd = service.compileCommand(name: "no_such_\(UUID().uuidString)")
        #expect(cmd == nil)
    }

    @Test("dylibPath returns path with lib prefix and .dylib extension")
    func dylibPathFormat() {
        let path = service.dylibPath(name: "MyScript")
        #expect(path.contains("libMyScript.dylib"))
        #expect(path.contains(".build/debug/"))
    }
}
