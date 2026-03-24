//
//  CodeBlockSyntax+Terminal.swift
//  Agent
//
//  Terminal output highlighting extensions
//

import AppKit

// MARK: - Terminal Colors & Regexes
extension CodeBlockHighlighter {
    
    // Terminal output theme colors
    static var termDir: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 1)   // bright blue
            : NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1)
    }
    static var termExec: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1)    // green
            : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1)
    }
    static var termSymlink: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.9, green: 0.5, blue: 0.9, alpha: 1)    // magenta
            : NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1)
    }
    static var termSize: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.85, green: 0.85, blue: 0.5, alpha: 1)  // yellow
            : NSColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 1)
    }
    static var termDate: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1)    // dim
            : NSColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
    }
    static var termPerm: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.6, green: 0.7, blue: 0.6, alpha: 1)    // muted green
            : NSColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1)
    }
    static var termPath: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.4, green: 0.85, blue: 0.85, alpha: 1)  // cyan
            : NSColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1)
    }
    static var termError: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1)    // red
            : NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1)
    }
    static var termWarning: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)    // yellow
            : NSColor(red: 0.7, green: 0.5, blue: 0.0, alpha: 1)
    }

    // Precompiled regexes for terminal output
    static let termPermRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"^[d\-lbcps][rwxstTSl\-]{9}[.@+\s]?"#, options: .anchorsMatchLines)
    static let termTotalRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"^total\s+\d+"#, options: .anchorsMatchLines)
    static let termDateRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+(?:\d{4}|\d{1,2}:\d{2})"#)
    static let termPathRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?:^|\s)((?:/[\w.\-@]+)+/?)"#, options: .anchorsMatchLines)
    static let termArrowRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\s->\s.*$"#, options: .anchorsMatchLines)
    static let termErrorRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:error|Error|ERROR|fatal|FATAL|failed|FAILED|No such file|Permission denied|not found|cannot)\b"#)
    static let termWarningRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:warning|Warning|WARNING|deprecated|DEPRECATED|caution)\b"#)
    static let termSizeRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?<=\s)\d{1,12}(?=\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))"#)
}