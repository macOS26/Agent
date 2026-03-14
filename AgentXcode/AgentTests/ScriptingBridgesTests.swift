import Testing
import Foundation
@testable import Agent_

@Suite("ScriptingBridges Bundle")
struct ScriptingBridgesTests {

    // MARK: - Bundle Presence

    @Test("XCFScriptingBridges folder exists in app bundle Sources")
    func bridgesFolderExists() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Sources/XCFScriptingBridges"
        #expect(FileManager.default.fileExists(atPath: path),
                "Expected XCFScriptingBridges at \(path)")
    }

    @Test("AgentScriptingBridge.swift exists in bundle")
    func agentScriptingBridgeExists() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Sources/XCFScriptingBridges/AgentScriptingBridge.swift"
        #expect(FileManager.default.fileExists(atPath: path),
                "Expected AgentScriptingBridge.swift at \(path)")
    }

    @Test("ScriptingBridgeCommon.swift exists in bundle")
    func commonBridgeExists() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Sources/XCFScriptingBridges/ScriptingBridgeCommon.swift"
        #expect(FileManager.default.fileExists(atPath: path),
                "Expected ScriptingBridgeCommon.swift at \(path)")
    }

    @Test("ScriptingBridgeCommon.swift contains SBObjectProtocol")
    func commonHasBaseProtocol() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Sources/XCFScriptingBridges/ScriptingBridgeCommon.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content?.contains("SBObjectProtocol") == true)
        #expect(content?.contains("SBApplicationProtocol") == true)
    }

    // MARK: - Scripts folder

    @Test("Scripts folder exists in bundle Sources")
    func scriptsFolderExists() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Sources/Scripts"
        #expect(FileManager.default.fileExists(atPath: path),
                "Expected Scripts folder at \(path)")
    }

    @Test("Package.swift exists in bundle")
    func packageSwiftExists() {
        guard let resourcePath = Bundle.main.resourcePath else {
            #expect(Bool(false), "No resource path")
            return
        }
        let path = resourcePath + "/Package.swift"
        #expect(FileManager.default.fileExists(atPath: path),
                "Expected Package.swift at \(path)")
    }
}
