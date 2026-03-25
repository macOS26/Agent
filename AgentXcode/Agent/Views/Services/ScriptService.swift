import Foundation
import Darwin

@MainActor
final class ScriptService {
    static let agentsDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/AgentScript/agents")
    }()

    private var sourcesDir: URL { Self.agentsDir.appendingPathComponent("Sources") }
    private var scriptsDir: URL { sourcesDir.appendingPathComponent("Scripts") }

    /// Directory for saved AppleScript files
    static let applescriptDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/AgentScript/applescript")
    }()

    /// Directory for saved JavaScript (JXA) files
    static let javascriptDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/AgentScript/javascript")
    }()

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
        Bundle.main.resourceURL?.appendingPathComponent("AgentScript/agents/Sources")
    }
    private var bundleScripts: URL? {
        bundleSources?.appendingPathComponent("Scripts")
    }

    /// Path to the AppleEventBridges package bundled in app resources
    private static let bundledBridgesPath: URL? = {
        Bundle.main.resourceURL?.appendingPathComponent("bridges")
    }()

    /// Installed location: ~/Documents/AgentScript/bridges/
    static let installedBridgesPath: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/AgentScript/bridges")
    }()
    // MARK: - Package.swift generation

    /// Generate a clean Package.swift from the actual files on disk.
    /// Uses AppleEventBridges package dependency for bridge modules.
    private func generatePackageSwift() {
        let fm = FileManager.default

        // Discover scripts on disk
        let scriptFiles = (try? fm.contentsOfDirectory(atPath: scriptsDir.path)) ?? []
        let scriptNames = scriptFiles
            .filter { $0.hasSuffix(".swift") }
            .map { $0.replacingOccurrences(of: ".swift", with: "") }
            .filter { !$0.isEmpty }
            .sorted()

        let scriptList = scriptNames.map { "    \"\($0)\"," }.joined(separator: "\n")

        // Read bridge names from the installed copy at ~/Documents/AgentScript/bridges/
        let bridgesPackagePath = Self.installedBridgesPath.appendingPathComponent("Sources/AppleEventBridges")
        let bridgeNames: [String] = {
            let fm = FileManager.default
            guard let files = try? fm.contentsOfDirectory(atPath: bridgesPackagePath.path) else { return [] }
            return files
                .filter { $0.hasSuffix("Bridge.swift") && $0 != "ScriptingBridgeCommon.swift" }
                .map { $0.replacingOccurrences(of: ".swift", with: "") }
                .sorted()
        }()

        let content = """
        // swift-tools-version: 6.2
        import PackageDescription
        import Foundation

        // Scripts compile as dynamic libraries (.dylib) loaded into Agent! via dlopen.
        // ScriptService adds/removes entries when scripts are created/deleted.
        let scriptNames = [
        \(scriptList)
        ]

        // Bridge names match those in AppleEventBridges package
        let bridgeNames = [
        \(bridgeNames.map { "    \"\($0)\"," }.joined(separator: "\n"))
        ]

        let scripts = "Sources/Scripts"
        let bridgeNameSet = Set(bridgeNames)

        // Local package dependency for shared bridges (installed at ~/Documents/AgentScript/bridges/)
        let packageDependencies: [PackageDescription.Package.Dependency] = [
            .package(name: "AppleEventBridges", path: "\(Self.installedBridgesPath.path)")
        ]

        // Build Target.Dependency for each bridge (explicit package reference)
        func bridgeDep(_ name: String) -> Target.Dependency {
            .product(name: name, package: "AppleEventBridges")
        }

        // Auto-detect bridge imports in each script
        func parseDeps(for name: String) -> [Target.Dependency] {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent(scripts).appendingPathComponent("\\(name).swift")
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            var deps: [Target.Dependency] = []
            for line in contents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("import ") {
                    let module = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    if bridgeNameSet.contains(module) {
                        deps.append(bridgeDep(module))
                    } else if module == "ScriptingBridgeCommon" {
                        deps.append(bridgeDep("ScriptingBridgeCommon"))
                    } else if module == "AgentAccessibility" {
                        deps.append(.init(stringLiteral: "AgentAccessibility"))
                    }
                }
                if !trimmed.isEmpty && !trimmed.hasPrefix("import ") &&
                   !trimmed.hasPrefix("//") && !trimmed.hasPrefix("@") {
                    break
                }
            }
            return deps
        }

        let allScriptFiles = scriptNames.map { "\\($0).swift" }

        let scriptProducts: [Product] = scriptNames.map {
            .library(name: $0, type: .dynamic, targets: [$0])
        }

        let coreTargets: [Target] = [
            .target(name: "AgentAccessibility", path: "Sources/AgentAccessibility"),
        ]

        let scriptTargets: [Target] = scriptNames.map { name in
            .target(name: name, dependencies: parseDeps(for: name), path: scripts,
                    exclude: allScriptFiles.filter { $0 != "\\(name).swift" },
                    sources: ["\\(name).swift"])
        }

        let package = Package(
            name: "agents",
            platforms: [.macOS(.v26)],
            products: scriptProducts,
            dependencies: packageDependencies,
            targets: coreTargets + scriptTargets
        )
        """

        // Remove leading whitespace from each line (heredoc indentation)
        let trimmed = content.components(separatedBy: "\n")
            .map { line in
                var s = line
                while s.hasPrefix("        ") { s = String(s.dropFirst(8)) }
                return s
            }
            .joined(separator: "\n")

        try? trimmed.write(to: packageSwiftURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Ensure package

    /// Ensure ~/Documents/AgentScript/agents/ exists with scripts and Package.swift
    func ensurePackage() {
        packageLock.lock()
        defer { packageLock.unlock() }

        let fm = FileManager.default
        let agentsPath = Self.agentsDir.path

        // Migrate: rename AppleEventBridges → bridges and regenerate Package.swift
        let oldBridgesPath = fm.homeDirectoryForCurrentUser.appendingPathComponent("Documents/AgentScript/AppleEventBridges")
        var didMigrateBridges = false
        if fm.fileExists(atPath: oldBridgesPath.path) && !fm.fileExists(atPath: Self.installedBridgesPath.path) {
            try? fm.moveItem(at: oldBridgesPath, to: Self.installedBridgesPath)
            didMigrateBridges = true
        }

        if !fm.fileExists(atPath: agentsPath) {
            // Fresh install — copy sources from bundle and generate Package.swift
            copyEntirePackage()
            generatePackageSwift()
        } else {
            // Existing install — add new scripts and update bridges
            installNewScripts()
            copyBridgesPackage()
            if didMigrateBridges {
                // Regenerate Package.swift so dependency path points to bridges/
                generatePackageSwift()
            }
        }
        copyBundledJSONFiles()
    }


    // MARK: - JSON files

    /// The parent directory ~/Documents/AgentScript/ where JSON input/output files live
    static let agentDir: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/AgentScript")
    }()

    /// Copy any bundled .json files to ~/Documents/AgentScript/json/ if they don't already exist
    private func copyBundledJSONFiles() {
        let fm = FileManager.default
        guard let bundleURL = Bundle.main.resourceURL else { return }

        try? fm.createDirectory(at: Self.agentDir, withIntermediateDirectories: true)

        // Create organized output subfolders
        for sub in ["json", "photos", "images", "screenshots", "html", "applescript", "javascript", "logs", "recordings"] {
            try? fm.createDirectory(at: Self.agentDir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }

        let jsonDir = Self.agentDir.appendingPathComponent("json")
        guard let items = try? fm.contentsOfDirectory(atPath: bundleURL.path) else { return }
        for item in items where item.hasSuffix(".json") {
            let dst = jsonDir.appendingPathComponent(item)
            if !fm.fileExists(atPath: dst.path) {
                let src = bundleURL.appendingPathComponent(item)
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    // MARK: - Fresh install

    /// Copy entire bundled package to ~/Documents/AgentScript/agents/
    private func copyEntirePackage() {
        let fm = FileManager.default
        let dest = Self.agentsDir

        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        // Copy Sources/
        if let src = bundleSources {
            try? fm.copyItem(at: src, to: dest.appendingPathComponent("Sources"))
        }

        // Copy AppleEventBridges package
        copyBridgesPackage()

        // Package.swift is generated from disk contents by generatePackageSwift()
    }

    /// Copy AppleEventBridges package to ~/Documents/AgentScript/bridges/
    /// Only copies new files — never overwrites or removes user-added bridges.
    private func copyBridgesPackage() {
        let fm = FileManager.default
        guard let src = Self.bundledBridgesPath, fm.fileExists(atPath: src.path) else { return }
        let dest = Self.installedBridgesPath

        // Create destination if it doesn't exist
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        // Copy Package.swift (always update — generated from source files)
        let srcPkg = src.appendingPathComponent("Package.swift")
        let dstPkg = dest.appendingPathComponent("Package.swift")
        if fm.fileExists(atPath: srcPkg.path) {
            try? fm.removeItem(at: dstPkg)
            try? fm.copyItem(at: srcPkg, to: dstPkg)
        }

        // Copy Sources/ directories, only adding files that don't already exist
        let srcSources = src.appendingPathComponent("Sources")
        let dstSources = dest.appendingPathComponent("Sources")
        guard let sourceDirs = try? fm.contentsOfDirectory(atPath: srcSources.path) else { return }
        for dir in sourceDirs {
            let srcDir = srcSources.appendingPathComponent(dir)
            let dstDir = dstSources.appendingPathComponent(dir)
            try? fm.createDirectory(at: dstDir, withIntermediateDirectories: true)

            guard let files = try? fm.contentsOfDirectory(atPath: srcDir.path) else { continue }
            for file in files {
                let dstFile = dstDir.appendingPathComponent(file)
                if !fm.fileExists(atPath: dstFile.path) {
                    try? fm.copyItem(at: srcDir.appendingPathComponent(file), to: dstFile)
                }
            }
        }
    }

    // MARK: - Install new scripts

    // MARK: - Deleted scripts blocklist

    /// Scripts the user has explicitly deleted — don't re-copy from bundle
    private static let deletedScriptsKey = "agentDeletedScripts"

    private var deletedScripts: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.deletedScriptsKey) ?? [])
    }

    func markScriptDeleted(_ name: String) {
        var deleted = deletedScripts
        deleted.insert(name)
        UserDefaults.standard.set(Array(deleted), forKey: Self.deletedScriptsKey)
    }

    func unmarkScriptDeleted(_ name: String) {
        var deleted = deletedScripts
        deleted.remove(name)
        UserDefaults.standard.set(Array(deleted), forKey: Self.deletedScriptsKey)
    }


    /// Copy bundled scripts that don't already exist (preserve user modifications)
    /// Skips scripts the user has explicitly deleted via delete_agent.
    private func installNewScripts() {
        let fm = FileManager.default

        guard let bundleDir = bundleScripts,
              fm.fileExists(atPath: bundleDir.path) else { return }

        if !fm.fileExists(atPath: scriptsDir.path) {
            try? fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        }

        let blocked = deletedScripts
        guard let files = try? fm.contentsOfDirectory(atPath: bundleDir.path) else { return }
        for file in files where file.hasSuffix(".swift") {
            let name = file.replacingOccurrences(of: ".swift", with: "")
            let dst = scriptsDir.appendingPathComponent(file)
            if !fm.fileExists(atPath: dst.path) && !blocked.contains(name) {
                let src = bundleDir.appendingPathComponent(file)
                try? fm.copyItem(at: src, to: dst)
            }
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

    /// Format scripts as a numbered list
    func numberedList() -> String {
        let scripts = listScripts()
        guard !scripts.isEmpty else { return "No agents found in ~/Documents/AgentScript/agents/" }
        return scripts.enumerated().map { "#\($0.offset + 1) \($0.element.name) (\($0.element.size) bytes)" }.joined(separator: "\n")
    }

    /// Resolve a script name — accepts a name or a number like "#4" or "4"
    func resolveScriptName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        let numStr = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        if let num = Int(numStr) {
            let scripts = listScripts()
            if num >= 1 && num <= scripts.count {
                return scripts[num - 1].name
            }
        }
        return trimmed
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

    /// Convert a name to UpperCamelCase: "compress_dmg" → "CompressDmg", "hello" → "Hello"
    static func toUpperCamelCase(_ name: String) -> String {
        let parts = name.split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " })
        if parts.isEmpty { return name }
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Create a new script as Sources/Scripts/{name}.swift and register in Package.swift
    func createScript(name: String, content: String) -> String {
        // Ensure package exists first (without lock - just creates directories)
        ensurePackage()

        let raw = name.replacingOccurrences(of: ".swift", with: "")
            .replacingOccurrences(of: ".md", with: "")
        guard !raw.isEmpty else {
            return "Error: script name cannot be empty."
        }
        // Auto-convert to UpperCamelCase
        let scriptName = Self.toUpperCamelCase(raw)
        // Reject invalid names: pure numbers, names with dots, tool name conflicts
        let invalidNames: Set<String> = ["ListAgents", "RunAgent", "ReadAgent", "CreateAgent",
                                          "UpdateAgent", "DeleteAgent", "CombineAgents", "Agent"]
        if Int(scriptName) != nil {
            return "Error: script name cannot be a number. Use a descriptive name like 'MyScript'."
        }
        if scriptName.contains(".") {
            return "Error: script name cannot contain dots."
        }
        if invalidNames.contains(scriptName) {
            return "Error: '\(scriptName)' is a reserved tool name."
        }
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        if fm.fileExists(atPath: scriptFile.path) {
            return "Error: script '\(scriptName)' already exists. Use update_agent to modify it."
        }

        let final = stripShebang(content)
        do {
            try fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            try final.write(to: scriptFile, atomically: true, encoding: .utf8)
            unmarkScriptDeleted(scriptName)

            // Regenerate Package.swift to include the new script
            packageLock.lock()
            defer { packageLock.unlock() }
            generatePackageSwift()
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
            return "Error: script '\(scriptName)' not found. Use create_agent to create it."
        }

        let final = stripShebang(content)
        do {
            try final.write(to: scriptFile, atomically: true, encoding: .utf8)
            return "Updated \(scriptName) (\(final.count) bytes)"
        } catch {
            return "Error updating script: \(error.localizedDescription)"
        }
    }

    /// Delete a script and remove from Package.swift (idempotent — succeeds even if file already gone)
    func deleteScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let scriptFile = scriptsDir.appendingPathComponent("\(scriptName).swift")
        let fm = FileManager.default

        // Remove file if it exists
        if fm.fileExists(atPath: scriptFile.path) {
            do {
                try fm.removeItem(at: scriptFile)
            } catch {
                return "Error deleting script: \(error.localizedDescription)"
            }
        }

        // Always mark deleted and regenerate Package.swift (self-heal stale entries)
        markScriptDeleted(scriptName)
        packageLock.lock()
        defer { packageLock.unlock() }
        generatePackageSwift()
        return "Deleted \(scriptName). Removed from Package.swift."
    }

    // MARK: - Package.swift path

    private var packageSwiftURL: URL {
        Self.agentsDir.appendingPathComponent("Package.swift")
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
        return "cd '\(agentsPath)' && touch Package.swift && swift build --product '\(scriptName)' 2>&1 && codesign --force --sign - --identifier \(AppConstants.bundleID) '\(dylibFile)' 2>&1"
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

    // MARK: - Out-of-Process Script Execution (concurrent)

    /// Path to the cached ScriptRunner helper executable.
    private static let runnerPath: String = {
        agentsDir.appendingPathComponent(".build/ScriptRunner").path
    }()

    private static let runnerSource = """
    import Foundation
    import Darwin

    guard CommandLine.arguments.count > 1 else {
        fputs("Usage: ScriptRunner <dylib-path>\\n", stderr)
        exit(1)
    }

    let dylibPath = CommandLine.arguments[1]

    guard let handle = dlopen(dylibPath, RTLD_NOW) else {
        let err = String(cString: dlerror())
        fputs("dlopen error: \\(err)\\n", stderr)
        exit(1)
    }

    guard let sym = dlsym(handle, "script_main") else {
        fputs("script_main not found\\n", stderr)
        dlclose(handle)
        exit(1)
    }

    // Line-buffered so output streams in real time
    setvbuf(stdout, nil, _IOLBF, 0)

    typealias ScriptMainFunc = @convention(c) () -> Int32
    let scriptMain = unsafeBitCast(sym, to: ScriptMainFunc.self)
    let status = scriptMain()
    dlclose(handle)
    exit(status)
    """

    /// Compile the ScriptRunner helper if it doesn't exist or is outdated.
    func ensureRunner() async -> Bool {
        let fm = FileManager.default
        let runnerPath = Self.runnerPath
        if fm.fileExists(atPath: runnerPath) { return true }

        let srcPath = Self.agentsDir.appendingPathComponent(".build/ScriptRunner.swift").path
        let buildDir = Self.agentsDir.appendingPathComponent(".build").path
        try? fm.createDirectory(atPath: buildDir, withIntermediateDirectories: true)
        try? Self.runnerSource.write(toFile: srcPath, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")
        process.arguments = ["-O", "-o", runnerPath, srcPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Run a compiled script dylib out-of-process via a small runner executable.
    /// Each invocation gets its own process with its own stdout — fully concurrent.
    func loadAndRunScriptViaProcess(name: String, arguments: String = "", captureStderr: Bool = false, isCancelled: (@Sendable () -> Bool)? = nil, onOutput: (@Sendable (String) -> Void)? = nil) async -> (output: String, status: Int32) {
        let scriptName = name.replacingOccurrences(of: ".swift", with: "")
        let dylib = dylibPath(name: scriptName)

        guard await ensureRunner() else {
            return ("Failed to compile ScriptRunner helper", 1)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.runnerPath)
        process.arguments = [dylib]

        // Inherit current environment and add script args
        var env = ProcessInfo.processInfo.environment
        if !arguments.isEmpty {
            env["AGENT_SCRIPT_ARGS"] = arguments
        }
        process.environment = env

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        if captureStderr {
            process.standardError = stdoutPipe
        }

        // Collected output buffer
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

        // Stream output as it arrives
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            collected.append(chunk)
            onOutput?(chunk)
        }

        do {
            try process.run()
        } catch {
            return ("Failed to launch script: \(error.localizedDescription)", 1)
        }

        // Wait for completion, checking cancellation
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                while process.isRunning {
                    if isCancelled?() == true {
                        process.terminate()
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
                process.waitUntilExit()
                // Drain any remaining output
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stdoutPipe.fileHandleForReading.availableData
                if !remaining.isEmpty,
                   let chunk = String(data: remaining, encoding: .utf8) {
                    collected.append(chunk)
                    onOutput?(chunk)
                }
                let status = process.terminationStatus
                continuation.resume(returning: (collected.output, status))
            }
        }
    }

    // MARK: - Saved AppleScripts (~/Documents/AgentScript/applescript/)

    /// List all saved .applescript files
    func listAppleScripts() -> [ScriptInfo] {
        let fm = FileManager.default
        let dir = Self.applescriptDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }

        return files.filter { $0.hasSuffix(".applescript") }.sorted().compactMap { file in
            let path = dir.appendingPathComponent(file).path
            guard let attrs = try? fm.attributesOfItem(atPath: path) else { return nil }
            let name = file.replacingOccurrences(of: ".applescript", with: "")
            return ScriptInfo(
                name: name,
                path: path,
                modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                size: attrs[.size] as? Int ?? 0
            )
        }
    }

    /// Read a saved AppleScript's source
    func readAppleScript(name: String) -> String? {
        let scriptName = name.replacingOccurrences(of: ".applescript", with: "")
        let file = Self.applescriptDir.appendingPathComponent("\(scriptName).applescript")
        return try? String(contentsOf: file, encoding: .utf8)
    }

    /// Save an AppleScript to disk (create or overwrite)
    func saveAppleScript(name: String, source: String) -> String {
        let fm = FileManager.default
        let dir = Self.applescriptDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let scriptName = name.replacingOccurrences(of: ".applescript", with: "")
        let file = dir.appendingPathComponent("\(scriptName).applescript")
        do {
            try source.write(to: file, atomically: true, encoding: .utf8)
            return "Saved \(scriptName).applescript (\(source.count) bytes)"
        } catch {
            return "Error saving: \(error.localizedDescription)"
        }
    }

    /// Delete a saved AppleScript
    func deleteAppleScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".applescript", with: "")
        let file = Self.applescriptDir.appendingPathComponent("\(scriptName).applescript")
        guard FileManager.default.fileExists(atPath: file.path) else {
            return "Error: '\(scriptName)' not found"
        }
        do {
            try FileManager.default.removeItem(at: file)
            return "Deleted \(scriptName).applescript"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Saved JavaScript/JXA (~/Documents/AgentScript/javascript/)

    func listJavaScripts() -> [ScriptInfo] {
        let fm = FileManager.default
        let dir = Self.javascriptDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }

        return files.filter { $0.hasSuffix(".js") }.sorted().compactMap { file in
            let path = dir.appendingPathComponent(file).path
            guard let attrs = try? fm.attributesOfItem(atPath: path) else { return nil }
            let name = file.replacingOccurrences(of: ".js", with: "")
            return ScriptInfo(name: name, path: path,
                              modifiedDate: attrs[.modificationDate] as? Date ?? Date(),
                              size: attrs[.size] as? Int ?? 0)
        }
    }

    func readJavaScript(name: String) -> String? {
        let scriptName = name.replacingOccurrences(of: ".js", with: "")
        let file = Self.javascriptDir.appendingPathComponent("\(scriptName).js")
        return try? String(contentsOf: file, encoding: .utf8)
    }

    func saveJavaScript(name: String, source: String) -> String {
        let fm = FileManager.default
        let dir = Self.javascriptDir
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let scriptName = name.replacingOccurrences(of: ".js", with: "")
        let file = dir.appendingPathComponent("\(scriptName).js")
        do {
            try source.write(to: file, atomically: true, encoding: .utf8)
            return "Saved \(scriptName).js (\(source.count) bytes)"
        } catch {
            return "Error saving: \(error.localizedDescription)"
        }
    }

    func deleteJavaScript(name: String) -> String {
        let scriptName = name.replacingOccurrences(of: ".js", with: "")
        let file = Self.javascriptDir.appendingPathComponent("\(scriptName).js")
        guard FileManager.default.fileExists(atPath: file.path) else {
            return "Error: '\(scriptName)' not found"
        }
        do {
            try FileManager.default.removeItem(at: file)
            return "Deleted \(scriptName).js"
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
