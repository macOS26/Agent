import Testing
import Foundation
@testable import Agent

@Suite("ScriptingBridges Bundle")
struct ScriptingBridgesTests {
    static let bridgesDir = Bundle.main.resourceURL?
        .appendingPathComponent("ScriptingBridges")

    static let expectedApps = [
        "Automator", "Calendar", "Common", "Contacts", "Finder",
        "ImageEvents", "Mail", "Messages", "Music", "Notes",
        "Numbers", "Pages", "Photos", "Reminders", "ScriptEditor",
        "Shortcuts", "SystemEvents", "Terminal", "TV", "Xcode"
    ]

    // MARK: - Bundle Presence

    @Test("ScriptingBridges folder exists in app bundle")
    func bridgesFolderExists() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges"
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("All expected bridge files are bundled")
    func allBridgeFilesPresent() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        let names = files.map { $0.replacingOccurrences(of: ".swift", with: "") }

        for app in Self.expectedApps {
            #expect(names.contains(app), "Missing bridge file: \(app).swift")
        }
    }

    @Test("Common.swift contains SBObjectProtocol")
    func commonHasBaseProtocol() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Common.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("SBObjectProtocol"))
        #expect(content!.contains("SBApplicationProtocol"))
    }

    @Test("Common.swift has exported imports")
    func commonHasExportedImports() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Common.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("@_exported import AppKit"))
        #expect(content!.contains("@_exported import ScriptingBridge"))
    }

    // MARK: - Bridge File Content

    @Test("Mail.swift contains MailApplication protocol")
    func mailBridgeContent() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Mail.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("MailApplication"))
        #expect(content!.contains("extension SBApplication: MailApplication"))
    }

    @Test("Finder.swift contains FinderApplication protocol")
    func finderBridgeContent() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Finder.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("FinderApplication"))
        #expect(content!.contains("extension SBApplication: FinderApplication"))
    }

    @Test("Calendar.swift contains CalendarApplication protocol")
    func calendarBridgeContent() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Calendar.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("CalendarApplication"))
    }

    @Test("Music.swift contains MusicApplication protocol")
    func musicBridgeContent() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges/Music.swift"
        let content = try? String(contentsOfFile: path, encoding: .utf8)
        #expect(content != nil)
        #expect(content!.contains("MusicApplication"))
    }

    @Test("No bridge file contains duplicate SBObjectProtocol")
    func noDuplicateBaseProtocols() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

        for file in files where file != "Common.swift" && file.hasSuffix(".swift") {
            let filePath = path + "/" + file
            let content = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
            #expect(!content.contains("protocol SBObjectProtocol"),
                    "\(file) still contains duplicate SBObjectProtocol")
            #expect(!content.contains("protocol SBApplicationProtocol"),
                    "\(file) still contains duplicate SBApplicationProtocol")
        }
    }

    @Test("No bridge file has its own import statements")
    func noStandaloneImports() {
        let path = Bundle.main.resourcePath! + "/ScriptingBridges"
        let files = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

        for file in files where file != "Common.swift" && file.hasSuffix(".swift") {
            let filePath = path + "/" + file
            let content = (try? String(contentsOfFile: filePath, encoding: .utf8)) ?? ""
            #expect(!content.hasPrefix("import AppKit"),
                    "\(file) has standalone import AppKit")
            #expect(!content.hasPrefix("import ScriptingBridge"),
                    "\(file) has standalone import ScriptingBridge")
        }
    }
}
