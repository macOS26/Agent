import Foundation
import Darwin

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

    // MARK: - Thread Safety
    
    /// Lock to prevent concurrent Package.swift modifications
    private let packageLock = NSLock()
    
    /// Serial queue for script compilation (prevents concurrent swift build calls)
    private nonisolated static let compilationQueue = DispatchQueue(label: "com.agent.scriptcompilation", qos: .userInitiated)

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
        packageLock.lock()
        defer { packageLock.unlock() }
        
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
        copyBundledJSONFiles()
        syncBridgesWithPackageLocked()
        syncScriptsWithPackageLocked()
    }

    /// Sync scriptNames in Package.swift with actual .swift files on disk.
    /// Adds unregistered scripts and removes entries for deleted files.
    /// MUST be called with packageLock held.
    private func syncScriptsWithPackageLocked() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: scriptsDir.path),
              fm.fileExists(atPath: packageSwiftURL.path) else { return }

        guard let files = try? fm.contentsOfDirectory(atPath: scriptsDir.path) else { return }
        let diskScripts = Set(files.filter { $0.hasSuffix(".swift") }
            .map { $0.replacingOccurrences(of: ".swift", with: "") })

        guard var content = try? String(contentsOf: packageSwiftURL, encoding: .utf8) else { return }
        content = syncArray(named: "let scriptNames = [", with: diskScripts, in: content)
        try? content.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    /// Sync bridgeNames in Package.swift with actual .swift files on disk.
    /// Excludes ScriptingBridgeCommon.swift and AgentScriptingBridge.swift (managed separately).
    /// MUST be called with packageLock held.
    private func syncBridgesWithPackageLocked() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: bridgesDir.path),
              fm.fileExists(atPath: packageSwiftURL.path) else { return }

        guard let files = try? fm.contentsOfDirectory(atPath: bridgesDir.path) else { return }
        let excluded: Set<String> = ["ScriptingBridgeCommon", "AgentScriptingBridge"]
        let diskBridges = Set(files.filter { $0.hasSuffix(".swift") }
            .map { $0.replacingOccurrences(of: ".swift", with: "") })
            .subtracting(excluded)

        guard var content = try? String(contentsOf: packageSwiftURL, encoding: .utf8) else { return }
        content = syncArray(named: "let bridgeNames = [", with: diskBridges, in: content)
        try? content.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    /// Replace the contents of a named array in Package.swift with the given set of names.
    /// Returns the updated content, or the original if unchanged.
    private func syncArray(named marker: String, with diskNames: Set<String>, in content: String) -> String {
        guard let arrayStart = content.range(of: marker) else { return content }
        guard let arrayEnd = content[arrayStart.upperBound...].range(of: "]") else { return content }

        let arrayContent = content[arrayStart.upperBound..<arrayEnd.lowerBound]
        let registered = Set(arrayContent.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\",")) }
            .filter { !$0.isEmpty })

        guard diskNames != registered else { return content }

        let sorted = diskNames.sorted()
        let newArray = sorted.map { "    \"\($0)\"," }.joined(separator: "\n")
        return String(content[..<arrayStart.upperBound]) + "\n" + newArray + "\n" + String(content[arrayEnd.lowerBound...])
    }

    // MARK: - JSON files

    /// The parent directory ~/Documents/Agent/ where JSON input/output files live
    static let agentDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/Agent")
    }()

    /// Copy any bundled .json files to ~/Documents/Agent/ if they don't already exist
    private func copyBundledJSONFiles() {
        let fm = FileManager.default
        guard let bundleURL = Bundle.main.resourceURL else { return }

        try? fm.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)

        guard let items = try? fm.contentsOfDirectory(atPath: bundleURL.path) else { return }
        for item in items where item.hasSuffix(".json") {
            let dst = Self.agentDir.appendingPathComponent(item)
            if !fm.fileExists(atPath: dst.path) {
                let src = bundleURL.appendingPathComponent(item)
                try? fm.copyItem(at: src, to: dst)
            }
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

    /// Copy Package.swift from bundle only if it doesn't exist (preserves user's scriptNames)
    private func copyPackageSwift() {
        let fm = FileManager.default
        guard let src = bundlePackage, fm.fileExists(atPath: src.path) else { return }
        let dst = Self.agentsDir.appendingPathComponent("Package.swift")
        if !fm.fileExists(atPath: dst.path) {
            try? fm.copyItem(at: src, to: dst)
        }
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

    /// Create a new script as Sources/Scripts/{name}.swift and register in Package.swift
    func createScript(name: String, content: String) -> String {
        // Ensure package exists first (without lock - just creates directories)
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
            
            // Hold lock while modifying Package.swift
            packageLock.lock()
            defer { packageLock.unlock() }
            addScriptToPackageLocked(scriptName)
            return "Created \(scriptName) (\(final.count) bytes). Registered in Package.swift."
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

    /// Delete a script and remove from Package.swift
    func deleteScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        if !fm.fileExists(atPath: scriptFile.path) {
            return "Error: script '\(scriptName)' not found."
        }

        do {
            try fm.removeItem(at: scriptFile)
            
            // Hold lock while modifying Package.swift
            packageLock.lock()
            defer { packageLock.unlock() }
            removeScriptFromPackageLocked(scriptName)
            return "Deleted \(scriptName). Removed from Package.swift."
        } catch {
            return "Error deleting script: \(error.localizedDescription)"
        }
    }

    // MARK: - Package.swift script registration

    private var packageSwiftURL: URL {
        Self.agentsDir.appendingPathComponent("Package.swift")
    }

    /// Add a script name to the scriptNames array in Package.swift
    /// MUST be called with packageLock held or from ensurePackage (which holds it).
    private func addScriptToPackageLocked(_ name: String) {
        guard let content = try? String(contentsOf: packageSwiftURL, encoding: .utf8) else { return }

        // Find the scriptNames array and insert the new name in sorted order
        guard let range = content.range(of: "let scriptNames = [") else { return }
        guard let closingBracket = content[range.upperBound...].range(of: "]") else { return }

        let arrayContent = content[range.upperBound..<closingBracket.lowerBound]
        var names = arrayContent.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\",")) }
            .filter { !$0.isEmpty }

        guard !names.contains(name) else { return }
        names.append(name)
        names.sort()

        let newArray = names.map { "    \"\($0)\"," }.joined(separator: "\n")
        let newContent = content[..<range.upperBound] + "\n" + newArray + "\n" + content[closingBracket.lowerBound...]

        try? String(newContent).write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    /// Remove a script name from the scriptNames array in Package.swift
    /// MUST be called with packageLock held or from ensurePackage (which holds it).
    private func removeScriptFromPackageLocked(_ name: String) {
        guard let content = try? String(contentsOf: packageSwiftURL, encoding: .utf8) else { return }

        // Find and remove the line containing this script name
        let lines = content.components(separatedBy: "\n")
        let pattern = "    \"\(name)\","
        let filtered = lines.filter { $0 != pattern }

        guard filtered.count < lines.count else { return }
        try? filtered.joined(separator: "\n").write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    /// Return the swift build command to compile a script as a dynamic library
    func compileCommand(name: String) -> String? {
        ensurePackage()
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default
        guard fm.fileExists(atPath: scriptFile.path) else { return nil }

        let agentsPath = Self.agentsDir.path
        let dylibFile = dylibPath(name: scriptName)
        // Re-sign dylib with the app's identity so macOS attributes AppleScript
        // permission prompts to "Agent!" instead of "Xcode"
        return "cd '\(agentsPath)' && touch Package.swift && swift build --product '\(scriptName)' 2>&1 && codesign --force --sign - --identifier Agent.app.toddbruss '\(dylibFile)' 2>&1"
    }

    /// Path to the compiled dylib for a script
    func dylibPath(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        return Self.agentsDir.appendingPathComponent(".build/debug/lib\(scriptName).dylib").path
    }

    /// Load and run a compiled script dylib in-process via dlopen/dlsym.
    /// Captures stdout (and optionally stderr) and returns the output + exit status.
    /// Runs on a background thread to avoid blocking the main thread.
    func loadAndRunScript(name: String, arguments: String = "", captureStderr: Bool = false, isCancelled: (@Sendable () -> Bool)? = nil, onOutput: (@Sendable (String) -> Void)? = nil) async -> (output: String, status: Int32) {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let path = dylibPath(name: scriptName)

        return await withCheckedContinuation { continuation in
            Self.compilationQueue.async {
                // Set arguments via environment variable for scripts that need them
                if !arguments.isEmpty {
                    setenv("AGENT_SCRIPT_ARGS", arguments, 1)
                }

                // Create pipe to capture stdout (and optionally stderr)
                var pipefd: [Int32] = [0, 0]
                pipe(&pipefd)
                let savedStdout = dup(STDOUT_FILENO)
                let savedStderr = captureStderr ? dup(STDERR_FILENO) : -1
                dup2(pipefd[1], STDOUT_FILENO)
                if captureStderr {
                    dup2(pipefd[1], STDERR_FILENO)
                }

                // Force line-buffered stdout so print() in dylibs flushes on each newline
                // (pipes default to full buffering which delays output until script exits)
                setvbuf(stdout, nil, _IOLBF, 0)
                if captureStderr {
                    setvbuf(stderr, nil, _IONBF, 0)
                }

                /// Restore stdout (and stderr if captured) to their original file descriptors.
                func restoreFDs() {
                    dup2(savedStdout, STDOUT_FILENO)
                    if captureStderr { dup2(savedStderr, STDERR_FILENO) }
                    setvbuf(stdout, nil, _IOFBF, 0)
                    if captureStderr { setvbuf(stderr, nil, _IOFBF, 0) }
                    close(savedStdout)
                    if captureStderr { close(savedStderr) }
                }

                // Load dylib
                guard let handle = dlopen(path, RTLD_NOW) else {
                    restoreFDs()
                    close(pipefd[0])
                    close(pipefd[1])
                    unsetenv("AGENT_SCRIPT_ARGS")
                    let err = String(cString: dlerror())
                    continuation.resume(returning: ("dlopen error: \(err)", 1))
                    return
                }

                // Find entry point
                guard let sym = dlsym(handle, "script_main") else {
                    dlclose(handle)
                    restoreFDs()
                    close(pipefd[0])
                    close(pipefd[1])
                    unsetenv("AGENT_SCRIPT_ARGS")
                    continuation.resume(returning: ("dlsym error: script_main not found in \(scriptName)", 1))
                    return
                }

                // Start a reader thread to stream pipe output to LogView
                final class OutputBuffer: @unchecked Sendable {
                    private let lock = NSLock()
                    private var buffer = ""
                    func append(_ chunk: String) {
                        lock.lock()
                        buffer += chunk
                        lock.unlock()
                    }
                    var output: String {
                        lock.lock()
                        defer { lock.unlock() }
                        return buffer
                    }
                }
                let collected = OutputBuffer()
                let readerQueue = DispatchQueue(label: "com.agent.script-output-reader")
                let readHandle = FileHandle(fileDescriptor: pipefd[0], closeOnDealloc: false)
                let readerDone = DispatchSemaphore(value: 0)

                readerQueue.async {
                    while true {
                        let data = readHandle.availableData
                        if data.isEmpty { break }
                        if let chunk = String(data: data, encoding: .utf8) {
                            collected.append(chunk)
                            onOutput?(chunk)
                        }
                    }
                    readerDone.signal()
                }

                // Check cancellation before running
                if isCancelled?() == true {
                    dlclose(handle)
                    fflush(stdout)
                    if captureStderr { fflush(stderr) }
                    close(pipefd[1])
                    restoreFDs()
                    readerDone.wait()
                    close(pipefd[0])
                    unsetenv("AGENT_SCRIPT_ARGS")
                    continuation.resume(returning: ("Cancelled before execution", -1))
                    return
                }

                // Call script_main
                typealias ScriptMainFunc = @convention(c) () -> Int32
                let scriptMain = unsafeBitCast(sym, to: ScriptMainFunc.self)
                let status = scriptMain()

                // Flush and restore
                fflush(stdout)
                if captureStderr { fflush(stderr) }
                close(pipefd[1])
                restoreFDs()

                // Wait for reader to finish draining the pipe
                readerDone.wait()
                close(pipefd[0])

                dlclose(handle)
                unsetenv("AGENT_SCRIPT_ARGS")

                continuation.resume(returning: (collected.output, status))
            }
        }
    }

    /// Block until any in-flight compilation/script work finishes.
    /// Call before exit to avoid stdout deadlock in C++ static destructors.
    nonisolated static func drainCompilationQueue() {
        compilationQueue.sync {}
    }
}
