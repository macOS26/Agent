import AppKit

// MARK: - Code Block Theme (Xcode Dark/Light palette from JibberJabber)

@MainActor public enum CodeBlockTheme {
    private static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static func c(_ d: UInt32, _ l: UInt32) -> NSColor {
        let h = isDark ? d : l
        return NSColor(
            red: CGFloat((h >> 16) & 0xFF) / 255,
            green: CGFloat((h >> 8) & 0xFF) / 255,
            blue: CGFloat(h & 0xFF) / 255, alpha: 1
        )
    }

    public static var keyword: NSColor { c(0xFF7AB2, 0xAD3DA4) }
    public static var string: NSColor { c(0xFC6A5D, 0xD12F1B) }
    public static var number: NSColor { c(0xD9C97C, 0x272AD8) }
    public static var comment: NSColor { c(0x6C9C5A, 0x536579) }
    public static var type: NSColor { c(0xD0A8FF, 0x3E8087) }
    public static var funcCall: NSColor { c(0x67B7A4, 0x316E74) }
    public static var sysFunc: NSColor { c(0xB281EB, 0x6C36A9) }
    public static var preproc: NSColor { c(0xFFA14F, 0x78492A) }
    public static var attr: NSColor { c(0xFD8F3F, 0x643820) }
    public static var prop: NSColor { c(0x4EB0CC, 0x3E8087) }
    public static var selfKw: NSColor { c(0xFF7AB2, 0xAD3DA4) }
    public static var ident: NSColor { c(0xDFDFE0, 0x000000) }
    public static var text: NSColor { c(0xDFDFE0, 0x000000) }
    public static var bg: NSColor { c(0x292A30, 0xF0F0F2) }
}
