import Foundation

@MainActor
final class ScriptService {
    static let agentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent/agents")
    }()

    private var sourcesDir: URL { Self.agentsDir.appendingPathComponent("Sources") }
    private var bridgesDir: URL { sourcesDir.appendingPathComponent("XCFScriptingBridges") }
    private var scriptsDir: URL { sourcesDir.appendingPathComponent("Scripts") }

    struct ScriptInfo {
        let name: String
        let path: String
        let modifiedDate: Date
        let size: Int
    }

    // MARK: - Bundle paths

    private var bundleSources: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Sources")
    }
    private var bundleBridges: URL? {
        bundleSources?.appendingPathComponent("XCFScriptingBridges")
    }
    private var bundleScripts: URL? {
        bundleSources?.appendingPathComponent("Scripts")
    }
    private var bundlePackage: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Package.swift")
    }

    // MARK: - Ensure package

    /// Ensure ~/Documents/Agent/agents/ exists with bridges, scripts, and Package.swift
    func ensurePackage() {
        let fm = FileManager.default
        let agentsPath = Self.agentsDir.path

        if !fm.fileExists(atPath: agentsPath) {
            // Fresh install — copy entire package from bundle
            copyEntirePackage()
        } else {
            // Existing install — update bridges, add new scripts only
            updateBridges()
            installNewScripts()
            copyPackageSwift()
        }
    }

    // MARK: - Fresh install

    /// Copy entire bundled package to ~/Documents/Agent/agents/
    private func copyEntirePackage() {
        let fm = FileManager.default
        let dest = Self.agentsDir

        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        // Copy Package.swift
        if let src = bundlePackage {
            try? fm.copyItem(at: src, to: dest.appendingPathComponent("Package.swift"))
        }

        // Copy Sources/
        if let src = bundleSources {
            try? fm.copyItem(at: src, to: dest.appendingPathComponent("Sources"))
        }
    }

    // MARK: - Update bridges

    /// Update bridge files from bundle if the bundle copy is newer
    private func updateBridges() {
        let fm = FileManager.default

        guard let bundleDir = bundleBridges,
              fm.fileExists(atPath: bundleDir.path) else { return }

        if !fm.fileExists(atPath: bridgesDir.path) {
            try? fm.createDirectory(at: bridgesDir, withIntermediateDirectories: true)
        }

        guard let files = try? fm.contentsOfDirectory(atPath: bundleDir.path) else { return }
        for file in files where file.hasSuffix(".swift") {
            let src = bundleDir.appendingPathComponent(file)
            let dst = bridgesDir.appendingPathComponent(file)

            if !fm.fileExists(atPath: dst.path) {
                // New bridge — just copy
                try? fm.copyItem(at: src, to: dst)
            } else if isNewer(src, than: dst) {
                // Bundle is newer — overwrite
                try? fm.removeItem(at: dst)
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    // MARK: - Install new scripts

    /// Copy bundled scripts that don't already exist (preserve user modifications)
    private func installNewScripts() {
        let fm = FileManager.default

        guard let bundleDir = bundleScripts,
              fm.fileExists(atPath: bundleDir.path) else { return }

        if !fm.fileExists(atPath: scriptsDir.path) {
            try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        }

        guard let files = try? fm.contentsOfDirectory(atPath: bundleDir.path) else { return }
        for file in files where file.hasSuffix(".swift") {
            let dst = scriptsDir.appendingPathComponent(file)
            if !fm.fileExists(atPath: dst.path) {
                let src = bundleDir.appendingPathComponent(file)
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    // MARK: - Package.swift

    /// Copy Package.swift from bundle (always overwrite to keep in sync with bridges)
    private func copyPackageSwift() {
        let fm = FileManager.default
        guard let src = bundlePackage, fm.fileExists(atPath: src.path) else { return }
        let dst = Self.agentsDir.appendingPathComponent("Package.swift")
        try? fm.removeItem(at: dst)
        try? fm.copyItem(at: src, to: dst)
    }

    // MARK: - Helpers

    /// Returns true if source file has a newer modification date than destination
    private func isNewer(_ src: URL, than dst: URL) -> Bool {
        let fm = FileManager.default
        guard let srcAttrs = try? fm.attributesOfItem(atPath: src.path),
              let dstAttrs = try? fm.attributesOfItem(atPath: dst.path),
              let srcDate = srcAttrs[.modificationDate] as? Date,
              let dstDate = dstAttrs[.modificationDate] as? Date else { return true }
        return srcDate > dstDate
    }

    // MARK: - Script CRUD

    /// List all scripts in Sources/Scripts/
    func listScripts() -> [ScriptInfo] {
        ensurePackage()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: scriptsDir.path) else { return [] }

        return files.filter { $0.hasSuffix(".swift") }.sorted().compactMap { file in
            let path = scriptsDir.appendingPathComponent(file).path
            guard let attrs = try? fm.attributesOfItem(atPath: path) else { return nil }
            let name = file.replacingOccurrences(of: ".swift", with: "")
            return ScriptInfo(
                name: name,
                path: path,
                modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                size: attrs[.size] as? Int ?? 0
            )
        }
    }

    /// Read a script's source code
    func readScript(name: String) -> String? {
        ensurePackage()
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        return try? String(contentsOf: scriptFile, encoding: .utf8)
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

    /// Create a new script as Sources/Scripts/{name}.swift
    func createScript(name: String, content: String) -> String {
        ensurePackage()
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        if fm.fileExists(atPath: scriptFile.path) {
            return "Error: script '\(scriptName)' already exists. Use update_agent_script to modify it."
        }

        let final = stripShebang(content)
        do {
            try fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            try final.write(to: scriptFile, atomically: true, encoding: .utf8)
            return "Created \(scriptName) (\(final.count) bytes). Auto-discovered by Package.swift — no manual registration needed."
        } catch {
            return "Error creating script: \(error.localizedDescription)"
        }
    }

    /// Update an existing script
    func updateScript(name: String, content: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        if !fm.fileExists(atPath: scriptFile.path) {
            return "Error: script '\(scriptName)' not found. Use create_agent_script to create it."
        }

        let final = stripShebang(content)
        do {
            try final.write(to: scriptFile, atomically: true, encoding: .utf8)
            return "Updated \(scriptName) (\(final.count) bytes)"
        } catch {
            return "Error updating script: \(error.localizedDescription)"
        }
    }

    /// Delete a script
    func deleteScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        if !fm.fileExists(atPath: scriptFile.path) {
            return "Error: script '\(scriptName)' not found."
        }

        do {
            try fm.removeItem(at: scriptFile)
            return "Deleted \(scriptName). Auto-removed from Package.swift discovery."
        } catch {
            return "Error deleting script: \(error.localizedDescription)"
        }
    }

    /// Build the swift build + run command for a script
    func compileAndRunCommand(name: String, arguments: String = "") -> String? {
        ensurePackage()
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default
        guard fm.fileExists(atPath: scriptFile.path) else { return nil }

        let agentsPath = Self.agentsDir.path
        let args = arguments.isEmpty ? "" : " \(arguments)"

        return "cd '\(agentsPath)' && touch Package.swift && swift build --product '\(scriptName)' 2>&1 && .build/debug/'\(scriptName)'\(args) 2>&1"
    }
}
