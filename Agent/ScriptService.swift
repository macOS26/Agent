import Foundation

@MainActor
final class ScriptService {
    static let agentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent/agents")
    }()

    private var sourcesDir: URL { Self.agentsDir.appendingPathComponent("Sources") }

    struct ScriptInfo {
        let name: String
        let path: String
        let modifiedDate: Date
        let size: Int
    }

    /// Ensure the package directory structure exists, ScriptingBridges are installed, and Package.swift is present
    private func ensurePackage() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: sourcesDir.path) {
            try? fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        }
        installScriptingBridges()
        regeneratePackageSwift()
    }

    /// Copy ScriptingBridges from the app bundle to ~/Documents/Agent/agents/Sources/ if not already present
    private func installScriptingBridges() {
        let fm = FileManager.default
        let destDir = sourcesDir.appendingPathComponent("ScriptingBridges")
        guard !fm.fileExists(atPath: destDir.path) else { return }

        guard let bundleDir = Bundle.main.resourcePath.map({ URL(fileURLWithPath: $0) })?
            .appendingPathComponent("ScriptingBridges"),
              fm.fileExists(atPath: bundleDir.path) else { return }

        try? fm.copyItem(at: bundleDir, to: destDir)
    }

    /// Regenerate Package.swift based on existing script directories under Sources/
    private func regeneratePackageSwift() {
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        let dirs = (try? fm.contentsOfDirectory(atPath: sourcesPath))?.filter { name in
            // Skip the ScriptingBridges library directory
            guard name != "ScriptingBridges" else { return false }
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: sourcesPath + "/" + name, isDirectory: &isDir) && isDir.boolValue
        }.sorted() ?? []

        // Check if ScriptingBridges library exists
        let hasBridges = fm.fileExists(atPath: sourcesPath + "/ScriptingBridges")

        let bridgeTarget = hasBridges
            ? "        .target(name: \"ScriptingBridges\", path: \"Sources/ScriptingBridges\")"
            : nil

        let execTargets = dirs.map { name in
            let deps = hasBridges
                ? ", dependencies: [\"ScriptingBridges\"]"
                : ""
            return "        .executableTarget(name: \"\(name)\"\(deps), path: \"Sources/\(name)\")"
        }

        let allTargets = ([bridgeTarget].compactMap { $0 } + execTargets).joined(separator: ",\n")

        let packageSwift = """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "AgentScripts",
            platforms: [.macOS(.v15)],
            targets: [
        \(allTargets)
            ]
        )
        """

        let packagePath = Self.agentsDir.appendingPathComponent("Package.swift")
        try? packageSwift.write(to: packagePath, atomically: true, encoding: .utf8)
    }

    /// List all scripts (each is a directory under Sources/ containing main.swift)
    func listScripts() -> [ScriptInfo] {
        ensurePackage()
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        guard let dirs = try? fm.contentsOfDirectory(atPath: sourcesPath) else { return [] }

        return dirs.filter { $0 != "ScriptingBridges" }.sorted().compactMap { dirName in
            let mainPath = sourcesPath + "/" + dirName + "/main.swift"
            guard let attrs = try? fm.attributesOfItem(atPath: mainPath) else { return nil }
            return ScriptInfo(
                name: dirName,
                path: mainPath,
                modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                size: attrs[.size] as? Int ?? 0
            )
        }
    }

    /// Read a script's source code
    func readScript(name: String) -> String? {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let mainPath = sourcesDir.appendingPathComponent(scriptName).appendingPathComponent("main.swift")
        return try? String(contentsOf: mainPath, encoding: .utf8)
    }

    private static let shebang = "#!/usr/bin/env swift"

    /// Ensure content starts with a shebang line
    private func ensureShebang(_ content: String) -> String {
        if content.hasPrefix(Self.shebang) { return content }
        return Self.shebang + "\n" + content
    }

    /// Create a new script as Sources/{name}/main.swift
    func createScript(name: String, content: String) -> String {
        ensurePackage()
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptDir = sourcesDir.appendingPathComponent(scriptName)
        let mainFile = scriptDir.appendingPathComponent("main.swift")
        let fm = FileManager.default

        if fm.fileExists(atPath: mainFile.path) {
            return "Error: script '\(scriptName)' already exists. Use update_agent_script to modify it."
        }

        let final = ensureShebang(content)
        do {
            try fm.createDirectory(at: scriptDir, withIntermediateDirectories: true)
            try final.write(to: mainFile, atomically: true, encoding: .utf8)
            regeneratePackageSwift()
            return "Created \(scriptName) (\(final.count) bytes)"
        } catch {
            return "Error creating script: \(error.localizedDescription)"
        }
    }

    /// Update an existing script
    func updateScript(name: String, content: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let mainFile = sourcesDir.appendingPathComponent(scriptName).appendingPathComponent("main.swift")
        let fm = FileManager.default

        if !fm.fileExists(atPath: mainFile.path) {
            return "Error: script '\(scriptName)' not found. Use create_agent_script to create it."
        }

        let final = ensureShebang(content)
        do {
            try final.write(to: mainFile, atomically: true, encoding: .utf8)
            return "Updated \(scriptName) (\(final.count) bytes)"
        } catch {
            return "Error updating script: \(error.localizedDescription)"
        }
    }

    /// Delete a script (removes its entire Sources/{name}/ directory)
    func deleteScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptDir = sourcesDir.appendingPathComponent(scriptName)
        let fm = FileManager.default

        if !fm.fileExists(atPath: scriptDir.path) {
            return "Error: script '\(scriptName)' not found."
        }

        do {
            try fm.removeItem(at: scriptDir)
            regeneratePackageSwift()
            return "Deleted \(scriptName)"
        } catch {
            return "Error deleting script: \(error.localizedDescription)"
        }
    }

    /// Build the swift build + run command for a script
    func compileAndRunCommand(name: String, arguments: String = "") -> String? {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let mainFile = sourcesDir.appendingPathComponent(scriptName).appendingPathComponent("main.swift")
        let fm = FileManager.default
        guard fm.fileExists(atPath: mainFile.path) else { return nil }

        let agentsPath = Self.agentsDir.path
        let args = arguments.isEmpty ? "" : " \(arguments)"

        return "cd '\(agentsPath)' && swift build --product '\(scriptName)' 2>&1 && .build/debug/'\(scriptName)'\(args) 2>&1"
    }
}
