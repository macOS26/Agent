import AppKit

// MARK: - Path Colorization Helpers

extension CodeBlockHighlighter {

    // Path segment colors for multi-color file path highlighting
    public static var pathHome: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1)   // dim gray
            : NSColor(red: 0.45, green: 0.45, blue: 0.5, alpha: 1)
    }
    public static var pathTopDir: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.6, green: 0.75, blue: 0.55, alpha: 1)  // muted green
            : NSColor(red: 0.3, green: 0.5, blue: 0.25, alpha: 1)
    }
    public static var pathMiddle: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.816, green: 0.659, blue: 1.0, alpha: 1)  // lavender
            : NSColor(red: 0.4, green: 0.2, blue: 0.7, alpha: 1)
    }
    public static var pathFilename: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 1)   // bright blue
            : NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1)
    }

    /// Apply multi-color highlighting to a file path within an attributed string.
    /// Segments: /Users/<user>/ → dim, top-level dir → green, middle dirs → cyan, filename → blue bold
    public static func colorizePath(_ result: NSMutableAttributedString, pathRange: NSRange, path: String, bold: NSFont) {
        var cursor = pathRange.location
        let ns = path as NSString

        // If path starts with /Users/<name>/ color that prefix dim
        if path.hasPrefix("/Users/") || path.hasPrefix("/var/") {
            // Find third slash: /Users/toddbruss/
            var slashCount = 0
            var homeEnd = 0
            for (i, ch) in path.enumerated() {
                if ch == "/" { slashCount += 1 }
                if slashCount == 3 { homeEnd = i + 1; break }
            }
            if homeEnd == 0 { homeEnd = ns.length }
            let homeRange = NSRange(location: cursor, length: homeEnd)
            result.addAttribute(.foregroundColor, value: pathHome, range: homeRange)
            cursor += homeEnd

            // Next component is the top-level dir (e.g. Documents, Library)
            let remaining = String(path.dropFirst(homeEnd))
            if let slashIdx = remaining.firstIndex(of: "/") {
                let topLen = remaining.distance(from: remaining.startIndex, to: slashIdx) + 1
                let topRange = NSRange(location: cursor, length: topLen)
                result.addAttribute(.foregroundColor, value: pathTopDir, range: topRange)
                cursor += topLen
            }
        } else if path.hasPrefix("~/") {
            // ~/ prefix → dim
            let homeRange = NSRange(location: cursor, length: 2)
            result.addAttribute(.foregroundColor, value: pathHome, range: homeRange)
            cursor += 2

            // Next component is the top-level dir
            let remaining = String(path.dropFirst(2))
            if let slashIdx = remaining.firstIndex(of: "/") {
                let topLen = remaining.distance(from: remaining.startIndex, to: slashIdx) + 1
                let topRange = NSRange(location: cursor, length: topLen)
                result.addAttribute(.foregroundColor, value: pathTopDir, range: topRange)
                cursor += topLen
            }
        }

        // Find the filename (last component after final /)
        let pathEnd = pathRange.location + pathRange.length
        if let lastSlash = path.lastIndex(of: "/") {
            let filenameStart = path.distance(from: path.startIndex, to: lastSlash) + 1
            let filenameLen = ns.length - filenameStart
            if filenameLen > 0 {
                let filenameRange = NSRange(location: pathRange.location + filenameStart, length: filenameLen)
                // Middle directories: everything between cursor and filename
                let middleLen = (pathRange.location + filenameStart) - cursor
                if middleLen > 0 {
                    let middleRange = NSRange(location: cursor, length: middleLen)
                    result.addAttribute(.foregroundColor, value: pathMiddle, range: middleRange)
                }
                // Filename → bright blue bold
                result.addAttributes([.foregroundColor: pathFilename, .font: bold], range: filenameRange)
            } else {
                // Trailing slash, color remaining as middle
                let middleLen = pathEnd - cursor
                if middleLen > 0 {
                    result.addAttribute(.foregroundColor, value: pathMiddle, range: NSRange(location: cursor, length: middleLen))
                }
            }
        } else {
            // No slash — entire thing is a filename
            let remainLen = pathEnd - cursor
            if remainLen > 0 {
                result.addAttributes([.foregroundColor: pathFilename, .font: bold], range: NSRange(location: cursor, length: remainLen))
            }
        }
    }
}
