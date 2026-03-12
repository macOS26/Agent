import Foundation

struct DependencyStatus {
    let xcodeTools: Bool

    var allGood: Bool { xcodeTools }
}

struct DependencyChecker {
    static func check() -> DependencyStatus {
        let xcodeTools = FileManager.default.fileExists(atPath: "/usr/bin/clang")
        return DependencyStatus(xcodeTools: xcodeTools)
    }

    /// Launch the Xcode Command Line Tools installer via xcode-select --install
    static func installCommandLineTools() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["--install"]
        try? process.run()
    }
}
