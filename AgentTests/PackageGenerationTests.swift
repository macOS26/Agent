import Testing
import Foundation
@testable import Agent

@Suite("Package.swift Generation")
@MainActor
struct PackageGenerationTests {
    let service = ScriptService()

    @Test("Package.swift exists after ensurePackage via create")
    func packageSwiftCreated() {
        // Creating a script triggers ensurePackage which generates Package.swift
        _ = service.createScript(name: "pkg_test", content: "print(\"pkg\")")

        let packagePath = ScriptService.agentsDir.appendingPathComponent("Package.swift").path
        #expect(FileManager.default.fileExists(atPath: packagePath))

        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("swift-tools-version"))
        #expect(content!.contains("AgentScripts"))

        _ = service.deleteScript(name: "pkg_test")
    }

    @Test("Package.swift includes ScriptingBridges target when present")
    func packageIncludesBridgesTarget() {
        _ = service.createScript(name: "bridges_pkg_test", content: "// test")

        let packagePath = ScriptService.agentsDir.appendingPathComponent("Package.swift").path
        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)
        #expect(content != nil)

        let bridgesDir = ScriptService.agentsDir
            .appendingPathComponent("Sources/ScriptingBridges").path
        if FileManager.default.fileExists(atPath: bridgesDir) {
            #expect(content!.contains("\"ScriptingBridges\""))
            #expect(content!.contains(".target(name: \"ScriptingBridges\""))
        }

        _ = service.deleteScript(name: "bridges_pkg_test")
    }

    @Test("Package.swift lists created script as executable target")
    func packageIncludesScriptTarget() {
        _ = service.createScript(name: "target_test", content: "// target")

        let packagePath = ScriptService.agentsDir.appendingPathComponent("Package.swift").path
        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("\"target_test\""))
        #expect(content!.contains(".executableTarget"))

        _ = service.deleteScript(name: "target_test")
    }

    @Test("Package.swift removes deleted script target")
    func packageRemovesDeletedTarget() {
        _ = service.createScript(name: "remove_test", content: "// remove")
        _ = service.deleteScript(name: "remove_test")

        let packagePath = ScriptService.agentsDir.appendingPathComponent("Package.swift").path
        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)
        #expect(content != nil)
        #expect(!content!.contains("\"remove_test\""))
    }

    @Test("Script targets depend on ScriptingBridges")
    func scriptsDependOnBridges() {
        _ = service.createScript(name: "dep_test", content: "// dep")

        let packagePath = ScriptService.agentsDir.appendingPathComponent("Package.swift").path
        let content = try? String(contentsOfFile: packagePath, encoding: .utf8)
        #expect(content != nil)

        let bridgesDir = ScriptService.agentsDir
            .appendingPathComponent("Sources/ScriptingBridges").path
        if FileManager.default.fileExists(atPath: bridgesDir) {
            #expect(content!.contains("dependencies: [\"ScriptingBridges\"]"))
        }

        _ = service.deleteScript(name: "dep_test")
    }
}
