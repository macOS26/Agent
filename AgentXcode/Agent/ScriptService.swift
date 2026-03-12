import Foundation

@MainActor
final class ScriptService {
    static let agentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent/agents")
    }()

    private var sourcesDir: URL { Self.agentsDir.appendingPathComponent("Sources") }
    private var bridgesDir: URL { sourcesDir.appendingPathComponent("ScriptingBridges") }

    /// Names of infrastructure directories under Sources/ that are not user scripts
    private static let reservedDirs: Set<String> = ["ScriptingBridges"]

    struct ScriptInfo {
        let name: String
        let path: String
        let modifiedDate: Date
        let size: Int
    }

    /// Ensure the package directory structure exists, bridges and example scripts are installed, and Package.swift is present
    private func ensurePackage() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: sourcesDir.path) {
            try? fm.createDirectory(at: sourcesDir, withIntermediateDirectories: true)
        }
        installScriptingBridges()
        installExampleScripts()
        regeneratePackageSwift()
    }

    // MARK: - Bridge Installation

    /// Install ScriptingBridges as individual per-app bridge targets inside Sources/ScriptingBridges/
    private func installScriptingBridges() {
        let fm = FileManager.default

        // Migrate from old layouts if present
        migrateFlatBridgesIfNeeded()
        migrateOldMonolithicIfNeeded()

        if !fm.fileExists(atPath: bridgesDir.path) {
            try? fm.createDirectory(at: bridgesDir, withIntermediateDirectories: true)
        }

        let commonDir = bridgesDir.appendingPathComponent("ScriptingBridgeCommon")

        guard let bundleDir = Bundle.main.resourcePath.map({ URL(fileURLWithPath: $0) })?
            .appendingPathComponent("ScriptingBridges"),
              fm.fileExists(atPath: bundleDir.path) else { return }

        // Always update ScriptingBridgeCommon (Common.swift) from bundle
        if !fm.fileExists(atPath: commonDir.path) {
            try? fm.createDirectory(at: commonDir, withIntermediateDirectories: true)
        }
        let commonSrc = bundleDir.appendingPathComponent("Common.swift")
        let commonDst = commonDir.appendingPathComponent("Common.swift")
        if fm.fileExists(atPath: commonSrc.path) {
            try? fm.removeItem(at: commonDst)
            try? fm.copyItem(at: commonSrc, to: commonDst)
        }

        // Always update individual bridge targets from bundle with import prepended.
        guard let files = try? fm.contentsOfDirectory(atPath: bundleDir.path) else { return }
        for file in files where file.hasSuffix(".swift") && file != "Common.swift" {
            let bridgeName = file.replacingOccurrences(of: ".swift", with: "") + "Bridge"
            let bridgeDir = bridgesDir.appendingPathComponent(bridgeName)
            let dst = bridgeDir.appendingPathComponent(file)

            if !fm.fileExists(atPath: bridgeDir.path) {
                try? fm.createDirectory(at: bridgeDir, withIntermediateDirectories: true)
            }
            let src = bundleDir.appendingPathComponent(file)
            if let content = try? String(contentsOf: src, encoding: .utf8) {
                let withImport = "@_exported import ScriptingBridgeCommon\n\n" + content
                try? withImport.write(to: dst, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Migrate *Bridge dirs and ScriptingBridgeCommon from Sources/ flat layout into Sources/ScriptingBridges/
    private func migrateFlatBridgesIfNeeded() {
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        guard let dirs = try? fm.contentsOfDirectory(atPath: sourcesPath) else { return }

        let flatBridges = dirs.filter { $0.hasSuffix("Bridge") || $0 == "ScriptingBridgeCommon" }
        guard !flatBridges.isEmpty else { return }

        if !fm.fileExists(atPath: bridgesDir.path) {
            try? fm.createDirectory(at: bridgesDir, withIntermediateDirectories: true)
        }

        for dirName in flatBridges {
            let src = sourcesDir.appendingPathComponent(dirName)
            let dst = bridgesDir.appendingPathComponent(dirName)
            if !fm.fileExists(atPath: dst.path) {
                try? fm.moveItem(at: src, to: dst)
            } else {
                try? fm.removeItem(at: src)
            }
        }
    }

    /// Migrate old monolithic ScriptingBridges directory to per-bridge layout
    private func migrateOldMonolithicIfNeeded() {
        let fm = FileManager.default
        let oldDir = sourcesDir.appendingPathComponent("ScriptingBridges")
        guard fm.fileExists(atPath: oldDir.path) else { return }

        let oldCommon = oldDir.appendingPathComponent("Common.swift")
        guard fm.fileExists(atPath: oldCommon.path) else { return }

        if !fm.fileExists(atPath: bridgesDir.path) {
            try? fm.createDirectory(at: bridgesDir, withIntermediateDirectories: true)
        }

        // Move Common.swift → Bridges/ScriptingBridgeCommon/
        let commonDir = bridgesDir.appendingPathComponent("ScriptingBridgeCommon")
        if !fm.fileExists(atPath: commonDir.path) {
            try? fm.createDirectory(at: commonDir, withIntermediateDirectories: true)
            try? fm.copyItem(at: oldCommon, to: commonDir.appendingPathComponent("Common.swift"))
        }

        // Move each bridge file → Bridges/{Name}Bridge/
        if let files = try? fm.contentsOfDirectory(atPath: oldDir.path) {
            for file in files where file.hasSuffix(".swift") && file != "Common.swift" {
                let bridgeName = file.replacingOccurrences(of: ".swift", with: "") + "Bridge"
                let bridgeDir = bridgesDir.appendingPathComponent(bridgeName)
                if !fm.fileExists(atPath: bridgeDir.path) {
                    try? fm.createDirectory(at: bridgeDir, withIntermediateDirectories: true)
                    let src = oldDir.appendingPathComponent(file)
                    let dst = bridgeDir.appendingPathComponent(file)
                    if let content = try? String(contentsOf: src, encoding: .utf8) {
                        let withImport = "@_exported import ScriptingBridgeCommon\n\n" + content
                        try? withImport.write(to: dst, atomically: true, encoding: .utf8)
                    }
                }
            }
        }

        try? fm.removeItem(at: oldDir)
        migrateScriptImports()
    }

    /// Update existing scripts from `import ScriptingBridges` to specific bridge imports
    private func migrateScriptImports() {
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        guard let dirs = try? fm.contentsOfDirectory(atPath: sourcesPath) else { return }

        for dirName in dirs where !isReservedDir(dirName) {
            let mainPath = sourcesPath + "/" + dirName + "/main.swift"
            guard let content = try? String(contentsOfFile: mainPath, encoding: .utf8),
                  content.contains("import ScriptingBridges") else { continue }

            let bridgeDeps = detectBridgeDependencies(in: content)

            if !bridgeDeps.isEmpty {
                let newImports = bridgeDeps.sorted().map { "import \($0)" }.joined(separator: "\n")
                let updated = content.replacingOccurrences(of: "import ScriptingBridges", with: newImports)
                try? updated.write(toFile: mainPath, atomically: true, encoding: .utf8)
            }
        }
    }

    /// Detect which bridge targets a script uses based on type prefixes in the source
    private func detectBridgeDependencies(in content: String) -> Set<String> {
        let bridges = installedBridgeTargets()
        var deps = Set<String>()
        for bridgeName in bridges {
            let baseName = bridgeName.replacingOccurrences(of: "Bridge", with: "")
            if content.contains(baseName + "Application") ||
               content.contains(baseName + "GenericMethods") ||
               content.range(of: "\\b\(baseName)\\w+", options: .regularExpression) != nil {
                deps.insert(bridgeName)
            }
        }
        return deps
    }

    // MARK: - Example Scripts

    /// Copy bundled example scripts to ~/Documents/Agent/agents/Sources/ (only if not already present)
    private func installExampleScripts() {
        let fm = FileManager.default
        guard let bundleDir = Bundle.main.resourcePath.map({ URL(fileURLWithPath: $0) })?
            .appendingPathComponent("ExampleScripts"),
              fm.fileExists(atPath: bundleDir.path),
              let examples = try? fm.contentsOfDirectory(atPath: bundleDir.path) else { return }

        for dirName in examples {
            let srcDir = bundleDir.appendingPathComponent(dirName)
            let destDir = sourcesDir.appendingPathComponent(dirName)
            guard !fm.fileExists(atPath: destDir.path) else { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: srcDir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            try? fm.copyItem(at: srcDir, to: destDir)
        }
    }

    // MARK: - Package.swift Generation

    /// Check if a directory name is reserved (not a user script)
    private func isReservedDir(_ name: String) -> Bool {
        Self.reservedDirs.contains(name)
    }

    /// Discover all installed bridge targets inside Sources/ScriptingBridges/
    private func installedBridgeTargets() -> [String] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(atPath: bridgesDir.path) else { return [] }
        return dirs.filter { $0.hasSuffix("Bridge") }.sorted()
    }

    /// Scan a script's main.swift for `import *Bridge` to determine its bridge dependencies
    private func scriptBridgeDeps(scriptName: String) -> [String] {
        let mainPath = sourcesDir.appendingPathComponent(scriptName)
            .appendingPathComponent("main.swift")
        guard let content = try? String(contentsOf: mainPath, encoding: .utf8) else { return [] }

        let bridges = installedBridgeTargets()
        return bridges.filter { bridge in
            content.contains("import \(bridge)")
        }
    }

    /// Regenerate Package.swift based on existing script directories and their bridge imports
    private func regeneratePackageSwift() {
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        let allDirs = (try? fm.contentsOfDirectory(atPath: sourcesPath))?.filter { name in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: sourcesPath + "/" + name, isDirectory: &isDir) && isDir.boolValue
        }.sorted() ?? []

        let hasCommon = fm.fileExists(atPath: bridgesDir.appendingPathComponent("ScriptingBridgeCommon").path)
        let bridgeTargets = installedBridgeTargets()
        let scriptDirs = allDirs.filter { !isReservedDir($0) }

        var targets: [String] = []

        // ScriptingBridgeCommon target
        if hasCommon {
            targets.append(
                "        .target(name: \"ScriptingBridgeCommon\", path: \"Sources/ScriptingBridges/ScriptingBridgeCommon\")"
            )
        }

        // Individual bridge targets (each depends on ScriptingBridgeCommon)
        for bridge in bridgeTargets {
            let dep = hasCommon ? ", dependencies: [\"ScriptingBridgeCommon\"]" : ""
            targets.append(
                "        .target(name: \"\(bridge)\"\(dep), path: \"Sources/ScriptingBridges/\(bridge)\")"
            )
        }

        // Executable script targets (depend on their imported bridges)
        for script in scriptDirs {
            let deps = scriptBridgeDeps(scriptName: script)
            let depStr: String
            if deps.isEmpty {
                depStr = ""
            } else {
                let depList = deps.map { "\"\($0)\"" }.joined(separator: ", ")
                depStr = ", dependencies: [\(depList)]"
            }
            targets.append(
                "        .executableTarget(name: \"\(script)\"\(depStr), path: \"Sources/\(script)\")"
            )
        }

        let allTargets = targets.joined(separator: ",\n")

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

    // MARK: - Script CRUD

    /// List all scripts (each is a directory under Sources/ containing main.swift)
    func listScripts() -> [ScriptInfo] {
        ensurePackage()
        let fm = FileManager.default
        let sourcesPath = sourcesDir.path
        guard let dirs = try? fm.contentsOfDirectory(atPath: sourcesPath) else { return [] }

        return dirs.filter { !isReservedDir($0) }.sorted().compactMap { dirName in
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

    /// Strip any shebang line — scripts are compiled via swift build, not run directly
    private func stripShebang(_ content: String) -> String {
        if content.hasPrefix("#!/") {
            if let newline = content.firstIndex(of: "\n") {
                return String(content[content.index(after: newline)...])
            }
        }
        return content
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

        let final = stripShebang(content)
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

        let final = stripShebang(content)
        do {
            try final.write(to: mainFile, atomically: true, encoding: .utf8)
            regeneratePackageSwift()
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
