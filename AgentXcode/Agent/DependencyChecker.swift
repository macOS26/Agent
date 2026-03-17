import Foundation

struct DependencyStatus {
    let xcodeTools: Bool
    let clang: Bool

    var allGood: Bool { xcodeTools && clang }
}

struct DependencyChecker {
    static func check() -> DependencyStatus {
        let fm = FileManager.default
        let xcodeTools = fm.fileExists(atPath: "/Library/Developer/CommandLineTools/usr/bin/clang")
        let clang = fm.fileExists(atPath: "/usr/bin/clang")
        return DependencyStatus(xcodeTools: xcodeTools, clang: clang)
    }

    /// Launch the Xcode Command Line Tools installer via xcode-select --install
    static func installCommandLineTools() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]
        try? process.run()
    }
}
