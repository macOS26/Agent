import AppKit

/// Retro neo green terminal color theme with dark/light mode support.
public enum TerminalNeoTheme: Sendable {
    private nonisolated(unsafe) static var _isDark: Bool = false

    @MainActor public static func updateAppearance() {
        _isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    public static var isDark: Bool { _isDark }

    public static var text: NSColor {
        isDark ? NSColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1)
               : NSColor(red: 0.05, green: 0.35, blue: 0.1, alpha: 1)
    }
    public static var bright: NSColor {
        isDark ? NSColor(red: 0.4, green: 0.95, blue: 0.4, alpha: 1)
               : NSColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1)
    }
    public static var dim: NSColor {
        isDark ? NSColor(red: 0.15, green: 0.4, blue: 0.2, alpha: 1)
               : NSColor(red: 0.3, green: 0.6, blue: 0.35, alpha: 1)
    }
    public static var border: NSColor {
        isDark ? NSColor(red: 0.2, green: 0.45, blue: 0.2, alpha: 1)
               : NSColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1)
    }
    public static var headerBg: NSColor {
        isDark ? NSColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1)
               : NSColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1)
    }
    public static var cellFg: NSColor {
        isDark ? NSColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
               : NSColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)
    }
    public static var evenBg: NSColor {
        isDark ? NSColor(red: 0.03, green: 0.08, blue: 0.03, alpha: 1)
               : NSColor(red: 0.9, green: 0.97, blue: 0.9, alpha: 1)
    }
    public static var oddBg: NSColor {
        isDark ? NSColor(red: 0.05, green: 0.12, blue: 0.05, alpha: 1)
               : NSColor(red: 0.87, green: 0.94, blue: 0.87, alpha: 1)
    }
    public static var codeBg: NSColor {
        isDark ? NSColor(red: 0.08, green: 0.15, blue: 0.08, alpha: 1)
               : NSColor(red: 0.85, green: 0.93, blue: 0.85, alpha: 1)
    }
}
