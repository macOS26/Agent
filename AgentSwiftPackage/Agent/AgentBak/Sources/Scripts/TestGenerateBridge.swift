import Foundation

@main
struct TestGenerateBridge {
    static func main() {
        testGenerateBridge()
    }
}

nonisolated(unsafe) private var passed = 0
nonisolated(unsafe) private var failed = 0

private func check(_ condition: Bool, _ message: String) {
    if condition {
        passed += 1
        print("  ✓ \(message)")
    } else {
        failed += 1
        print("  ✗ FAIL: \(message)")
    }
}

private func runCmd(_ cmd: String) -> (output: String, status: Int32) {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", cmd]
    process.standardOutput = pipe
    process.standardError = pipe
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
}

// MARK: - Test Helpers

private struct BridgeStats {
    let enumCount: Int
    let protocolCount: Int
    let enumNames: [String]
    let protocolNames: [String]
    let hasObjcAttributeLeak: Bool
    let hasDuplicateEnumValues: Bool
    let extensionCount: Int
}

private func analyzeBridge(_ content: String) -> BridgeStats {
    let lines = content.components(separatedBy: "\n")
    var enumNames: [String] = []
    var protocolNames: [String] = []
    var extensionCount = 0
    var hasObjcLeak = false

    let leakPatterns = ["NS_RETURNS_NOT_RETAINED", "NS_RETURNS_RETAINED", "__nullable", "__nonnull", "__kindof"]

    var hasDuplicates = false
    var inEnum = false
    var enumValues: Set<String> = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("@objc public enum ") {
            let name = trimmed
                .replacingOccurrences(of: "@objc public enum ", with: "")
                .components(separatedBy: " ").first ?? ""
            enumNames.append(name)
            inEnum = true
            enumValues = []
        }

        if trimmed.hasPrefix("@objc public protocol ") {
            let afterProtocol = trimmed.replacingOccurrences(of: "@objc public protocol ", with: "")
            let name = afterProtocol.components(separatedBy: ":").first?
                .components(separatedBy: " ").first?
                .trimmingCharacters(in: .init(charactersIn: " {")) ?? ""
            protocolNames.append(name)
        }

        if trimmed.hasPrefix("extension ") && trimmed.contains(":") && trimmed.hasSuffix("{}") {
            extensionCount += 1
        }

        if inEnum {
            if trimmed == "}" || trimmed == "}\n" {
                inEnum = false
            } else if trimmed.hasPrefix("case "), let eqRange = trimmed.range(of: " = ") {
                let value = String(trimmed[eqRange.upperBound...])
                    .components(separatedBy: " ").first ?? ""
                if enumValues.contains(value) {
                    hasDuplicates = true
                }
                enumValues.insert(value)
            }
        }

        for pattern in leakPatterns {
            if trimmed.contains(pattern) {
                hasObjcLeak = true
            }
        }
    }

    return BridgeStats(
        enumCount: enumNames.count,
        protocolCount: protocolNames.count,
        enumNames: enumNames,
        protocolNames: protocolNames,
        hasObjcAttributeLeak: hasObjcLeak,
        hasDuplicateEnumValues: hasDuplicates,
        extensionCount: extensionCount
    )
}

// MARK: - Entry Point

func testGenerateBridge() {
    let args = CommandLine.arguments
    let bridgesDir = args.count > 1
        ? args[1]
        : FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Agent/agents/Sources/Z-ScriptingBridges").path

    passed = 0
    failed = 0

    print("╔══════════════════════════════════════════════╗")
    print("║   generate_bridge — Automated Test Suite     ║")
    print("╚══════════════════════════════════════════════╝\n")

    let buildDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Agent/agents").path
    let generateBridgeBin = "\(buildDir)/.build/debug/GenerateBridge"

    print("Building GenerateBridge...")
    let buildResult = runCmd("cd '\(buildDir)' && swift build --product GenerateBridge 2>&1")
    guard buildResult.status == 0 else {
        print("FATAL: Build failed:\n\(buildResult.output)")
        exit(1)
    }
    print("Build OK\n")

    // Test 1: Mail.app
    print("━━━ Test 1: Mail.app (compare to reference) ━━━")

    let mailAppPath = "/System/Applications/Mail.app"
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("test_generate_bridge_\(ProcessInfo.processInfo.processIdentifier)").path
    try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

    let mailResult = runCmd("'\(generateBridgeBin)' '\(mailAppPath)' '\(tempDir)' 2>&1")
    check(mailResult.status == 0, "generate_bridge exits 0 for Mail.app")

    let generatedMailPath = "\(tempDir)/Mail.swift"
    let generatedMailExists = FileManager.default.fileExists(atPath: generatedMailPath)
    check(generatedMailExists, "Mail.swift output file created")

    if generatedMailExists {
        let generated = try! String(contentsOfFile: generatedMailPath, encoding: .utf8)
        let genStats = analyzeBridge(generated)

        check(genStats.enumCount == 12, "Mail enums: expected 12, got \(genStats.enumCount)")
        check(genStats.protocolCount == 29, "Mail protocols: expected 29, got \(genStats.protocolCount)")
        check(!genStats.hasObjcAttributeLeak, "No ObjC attribute leakage (NS_RETURNS_NOT_RETAINED, etc.)")
        check(!genStats.hasDuplicateEnumValues, "No duplicate enum raw values within same enum")

        let expectedProtocols = [
            "MailGenericMethods", "MailApplication", "MailMessage",
            "MailAccount", "MailMailbox", "MailOutgoingMessage",
            "MailRecipient", "MailRule", "MailSmtpServer"
        ]
        for proto in expectedProtocols {
            check(genStats.protocolNames.contains(proto), "Contains protocol: \(proto)")
        }

        let expectedEnums = [
            "MailSaveOptions", "MailQuotingColor", "MailViewerColumns",
            "MailAuthentication", "MailHighlightColors", "MailRuleType"
        ]
        for eName in expectedEnums {
            check(genStats.enumNames.contains(eName), "Contains enum: \(eName)")
        }

        check(genStats.extensionCount > 0, "Has SBObject extensions (\(genStats.extensionCount) found)")

        let referencePath = "\(bridgesDir)/Mail.swift"
        if FileManager.default.fileExists(atPath: referencePath) {
            let reference = try! String(contentsOfFile: referencePath, encoding: .utf8)
            let refStats = analyzeBridge(reference)

            check(genStats.enumCount == refStats.enumCount,
                   "Enum count matches reference (\(genStats.enumCount) vs \(refStats.enumCount))")
            check(genStats.protocolCount == refStats.protocolCount,
                   "Protocol count matches reference (\(genStats.protocolCount) vs \(refStats.protocolCount))")
            check(Set(genStats.protocolNames) == Set(refStats.protocolNames),
                   "Protocol names match reference")
            check(Set(genStats.enumNames) == Set(refStats.enumNames),
                   "Enum names match reference")

            check(generated.contains("newMailSound"), "Contains newMailSound property (NS_RETURNS_NOT_RETAINED regression test)")
            check(!generated.contains("NS_RETURNS_NOT_RETAINED"), "newMailSound not polluted by NS_RETURNS_NOT_RETAINED")
        } else {
            print("  ⚠ Reference Mail.swift not found at \(referencePath) — skipping comparison")
        }
    }

    // Test 2: Safari.app
    print("\n━━━ Test 2: Safari.app (fresh generation) ━━━")

    let safariPath = "/Applications/Safari.app"
    let safariResult = runCmd("'\(generateBridgeBin)' '\(safariPath)' '\(tempDir)' 2>&1")
    check(safariResult.status == 0, "generate_bridge exits 0 for Safari.app")

    let generatedSafariPath = "\(tempDir)/Safari.swift"
    if FileManager.default.fileExists(atPath: generatedSafariPath) {
        let safariContent = try! String(contentsOfFile: generatedSafariPath, encoding: .utf8)
        let safariStats = analyzeBridge(safariContent)

        check(safariStats.enumCount >= 1, "Safari has at least 1 enum (\(safariStats.enumCount) found)")
        check(safariStats.protocolCount >= 3, "Safari has at least 3 protocols (\(safariStats.protocolCount) found)")
        check(!safariStats.hasObjcAttributeLeak, "No ObjC attribute leakage in Safari output")
        check(safariStats.protocolNames.contains("SafariApplication"), "Contains SafariApplication protocol")

        let hasTabs = safariStats.protocolNames.contains { $0.contains("Tab") }
        let hasDocs = safariStats.protocolNames.contains { $0.contains("Document") }
        check(hasTabs || hasDocs, "Safari has Tab or Document protocol")
    } else {
        check(false, "Safari.swift output file created")
    }

    // Test 3: Messages.app
    print("\n━━━ Test 3: Messages.app (compare to reference) ━━━")

    let messagesPath = "/System/Applications/Messages.app"
    let messagesResult = runCmd("'\(generateBridgeBin)' '\(messagesPath)' '\(tempDir)' 2>&1")
    check(messagesResult.status == 0, "generate_bridge exits 0 for Messages.app")

    let generatedMsgPath = "\(tempDir)/Messages.swift"
    if FileManager.default.fileExists(atPath: generatedMsgPath) {
        let msgContent = try! String(contentsOfFile: generatedMsgPath, encoding: .utf8)
        let msgStats = analyzeBridge(msgContent)

        check(msgStats.enumCount >= 5, "Messages has at least 5 enums (\(msgStats.enumCount) found)")
        check(msgStats.protocolCount >= 6, "Messages has at least 6 protocols (\(msgStats.protocolCount) found)")
        check(!msgStats.hasObjcAttributeLeak, "No ObjC attribute leakage in Messages output")
        check(msgStats.protocolNames.contains("MessagesApplication"), "Contains MessagesApplication protocol")
        check(msgStats.protocolNames.contains("MessagesChat"), "Contains MessagesChat protocol")

        let msgRefPath = "\(bridgesDir)/Messages.swift"
        if FileManager.default.fileExists(atPath: msgRefPath) {
            let msgRef = try! String(contentsOfFile: msgRefPath, encoding: .utf8)
            let msgRefStats = analyzeBridge(msgRef)
            check(msgStats.enumCount == msgRefStats.enumCount,
                   "Messages enum count matches reference (\(msgStats.enumCount) vs \(msgRefStats.enumCount))")
            check(msgStats.protocolCount == msgRefStats.protocolCount,
                   "Messages protocol count matches reference (\(msgStats.protocolCount) vs \(msgRefStats.protocolCount))")
            check(Set(msgStats.protocolNames) == Set(msgRefStats.protocolNames),
                   "Messages protocol names match reference")
        } else {
            print("  ⚠ Reference Messages.swift not found — skipping comparison")
        }
    } else {
        check(false, "Messages.swift output file created")
    }

    // Test 4: Finder.app
    print("\n━━━ Test 4: Finder.app (deep protocol test) ━━━")

    let finderPath = "/System/Library/CoreServices/Finder.app"
    let finderResult = runCmd("'\(generateBridgeBin)' '\(finderPath)' '\(tempDir)' 2>&1")
    check(finderResult.status == 0, "generate_bridge exits 0 for Finder.app")

    let generatedFinderPath = "\(tempDir)/Finder.swift"
    if FileManager.default.fileExists(atPath: generatedFinderPath) {
        let finderContent = try! String(contentsOfFile: generatedFinderPath, encoding: .utf8)
        let finderStats = analyzeBridge(finderContent)

        check(finderStats.protocolCount >= 10, "Finder has at least 10 protocols (\(finderStats.protocolCount) found)")
        check(!finderStats.hasObjcAttributeLeak, "No ObjC attribute leakage in Finder output")
        check(finderStats.protocolNames.contains("FinderApplication"), "Contains FinderApplication protocol")

        let hasFolder = finderStats.protocolNames.contains { $0.contains("Folder") }
        let hasFile = finderStats.protocolNames.contains { $0.contains("File") }
        check(hasFolder, "Finder has Folder protocol")
        check(hasFile, "Finder has File protocol")

        let openBraces = finderContent.filter { $0 == "{" }.count
        let closeBraces = finderContent.filter { $0 == "}" }.count
        check(openBraces == closeBraces, "Balanced braces (\(openBraces) open, \(closeBraces) close)")
    } else {
        check(false, "Finder.swift output file created")
    }

    // Test 5: Error handling
    print("\n━━━ Test 5: Error handling ━━━")

    let badResult = runCmd("'\(generateBridgeBin)' /Applications/NonExistentApp.app '\(tempDir)' 2>&1")
    check(badResult.status != 0, "Non-existent app returns non-zero exit code")

    let noArgResult = runCmd("'\(generateBridgeBin)' 2>&1")
    check(noArgResult.status != 0, "No arguments returns non-zero exit code")
    check(noArgResult.output.contains("Usage"), "No arguments shows usage message")

    // Test 6: Compile check
    print("\n━━━ Test 6: Compile check (generated Mail.swift) ━━━")

    if FileManager.default.fileExists(atPath: generatedMailPath) {
        let compileDir = "\(tempDir)/compile_check"
        try? FileManager.default.createDirectory(atPath: compileDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(atPath: "\(compileDir)/Sources/CheckBridge", withIntermediateDirectories: true)

        let commonSrc = "\(bridgesDir)/Common.swift"
        if FileManager.default.fileExists(atPath: commonSrc) {
            try? FileManager.default.copyItem(atPath: commonSrc, toPath: "\(compileDir)/Sources/CheckBridge/Common.swift")
        }
        try? FileManager.default.copyItem(atPath: generatedMailPath, toPath: "\(compileDir)/Sources/CheckBridge/Mail.swift")

        let packageSwift = """
        // swift-tools-version: 6.0
        import PackageDescription
        let package = Package(
            name: "CheckBridge",
            platforms: [.macOS(.v15)],
            targets: [.target(name: "CheckBridge", path: "Sources/CheckBridge")]
        )
        """
        try? packageSwift.write(toFile: "\(compileDir)/Package.swift", atomically: true, encoding: .utf8)

        let compileResult = runCmd("cd '\(compileDir)' && swift build 2>&1")
        check(compileResult.status == 0, "Generated Mail.swift compiles successfully")
        if compileResult.status != 0 {
            let errorLines = compileResult.output.components(separatedBy: "\n")
                .filter { $0.contains("error:") }
                .prefix(5)
            for err in errorLines {
                print("    → \(err)")
            }
        }
    }

    try? FileManager.default.removeItem(atPath: tempDir)

    print("\n══════════════════════════════════════════════")
    print("Results: \(passed) passed, \(failed) failed")
    print("══════════════════════════════════════════════")

    exit(failed > 0 ? 1 : 0)
}
