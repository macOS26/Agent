import Foundation

@MainActor
final class ScriptService {
    static let agentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent/agents")
    }()

    struct ScriptInfo {
        let name: String
        let path: String
        let modifiedDate: Date
        let size: Int
    }

    /// Ensure the agents directory exists
    private func ensureDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.agentsDir.path) {
            try? fm.createDirectory(at: Self.agentsDir, withIntermediateDirectories: true)
        }
    }

    /// List all .swift scripts in ~/Documents/Agent/agents/
    func listScripts() -> [ScriptInfo] {
        ensureDirectory()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: Self.agentsDir.path) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .compactMap { filename in
                let path = Self.agentsDir.appendingPathComponent(filename).path
                guard let attrs = try? fm.attributesOfItem(atPath: path) else { return nil }
                return ScriptInfo(
                    name: filename,
                    path: path,
                    modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                    size: attrs[.size] as? Int ?? 0
                )
            }
    }

    /// Read a script's source code
    func readScript(name: String) -> String? {
        let filename = name.hasSuffix(".swift") ? name : name + ".swift"
        let path = Self.agentsDir.appendingPathComponent(filename)
        return try? String(contentsOf: path, encoding: .utf8)
    }

    /// Create a new script
    func createScript(name: String, content: String) -> String {
        ensureDirectory()
        let filename = name.hasSuffix(".swift") ? name : name + ".swift"
        let path = Self.agentsDir.appendingPathComponent(filename)
        let fm = FileManager.default
        if fm.fileExists(atPath: path.path) {
            return "Error: script '\(filename)' already exists. Use update_agent_script to modify it."
        }
        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            return "Created \(filename) (\(content.count) bytes)"
        } catch {
            return "Error creating script: \(error.localizedDescription)"
        }
    }

    /// Update an existing script
    func updateScript(name: String, content: String) -> String {
        let filename = name.hasSuffix(".swift") ? name : name + ".swift"
        let path = Self.agentsDir.appendingPathComponent(filename)
        let fm = FileManager.default
        if !fm.fileExists(atPath: path.path) {
            return "Error: script '\(filename)' not found. Use create_agent_script to create it."
        }
        do {
            try content.write(to: path, atomically: true, encoding: .utf8)
            return "Updated \(filename) (\(content.count) bytes)"
        } catch {
            return "Error updating script: \(error.localizedDescription)"
        }
    }

    /// Delete a script
    func deleteScript(name: String) -> String {
        let filename = name.hasSuffix(".swift") ? name : name + ".swift"
        let path = Self.agentsDir.appendingPathComponent(filename)
        let fm = FileManager.default
        if !fm.fileExists(atPath: path.path) {
            return "Error: script '\(filename)' not found."
        }
        do {
            try fm.removeItem(at: path)
            return "Deleted \(filename)"
        } catch {
            return "Error deleting script: \(error.localizedDescription)"
        }
    }

    /// Build the swiftc compile-and-run command for a script
    func compileAndRunCommand(name: String, arguments: String = "") -> String? {
        let filename = name.hasSuffix(".swift") ? name : name + ".swift"
        let scriptPath = Self.agentsDir.appendingPathComponent(filename).path
        let fm = FileManager.default
        guard fm.fileExists(atPath: scriptPath) else { return nil }

        // Read source to detect framework imports
        let source = (try? String(contentsOfFile: scriptPath, encoding: .utf8)) ?? ""
        var frameworks: [String] = []
        if source.contains("import ScriptingBridge") { frameworks.append("-framework ScriptingBridge") }
        if source.contains("import AppKit") { frameworks.append("-framework AppKit") }
        if source.contains("import WebKit") { frameworks.append("-framework WebKit") }

        let uuid = UUID().uuidString.prefix(8)
        let binary = "/tmp/agent_script_\(uuid)"
        let frameworkFlags = frameworks.isEmpty ? "" : " " + frameworks.joined(separator: " ")

        return "swiftc\(frameworkFlags) -o \(binary) '\(scriptPath)' 2>&1 && '\(binary)' \(arguments) 2>&1; EXIT=$?; rm -f '\(binary)'; exit $EXIT"
    }
}
