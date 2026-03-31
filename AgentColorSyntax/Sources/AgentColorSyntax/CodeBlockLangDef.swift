import AppKit

// MARK: - Language Definition

public struct LangDef: @unchecked Sendable {
    public let keywords: Set<String>
    public let declKeywords: Set<String>
    public let types: Set<String>
    public let selfKw: Set<String>
    public let sysFuncs: Set<String>
    public let commentPrefix: String?
    public let blockComStart: String?
    public let blockComEnd: String?
    public let hasAttrs: Bool
    public let hasPreproc: Bool
    public let stringRegex: NSRegularExpression?

    public init(kw: [String] = [], decl: [String] = [], types: [String] = [], selfKw: [String] = [],
         sys: [String] = [], comment: String? = "//", blockStart: String? = "/*", blockEnd: String? = "*/",
         attrs: Bool = false, preproc: Bool = false, strPat: String = #""(?:\\.|[^"\\])*""#) {
        self.keywords = Set(kw)
        self.declKeywords = Set(decl)
        self.types = Set(types)
        self.selfKw = Set(selfKw)
        self.sysFuncs = Set(sys)
        self.commentPrefix = comment
        self.blockComStart = blockStart
        self.blockComEnd = blockEnd
        self.hasAttrs = attrs
        self.hasPreproc = preproc
        self.stringRegex = try? NSRegularExpression(pattern: strPat)
    }
}
