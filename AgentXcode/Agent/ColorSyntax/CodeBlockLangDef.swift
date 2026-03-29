import AppKit

// MARK: - Language Definition

struct LangDef {
    let keywords: Set<String>
    let declKeywords: Set<String>
    let types: Set<String>
    let selfKw: Set<String>
    let sysFuncs: Set<String>
    let commentPrefix: String?
    let blockComStart: String?
    let blockComEnd: String?
    let hasAttrs: Bool
    let hasPreproc: Bool
    let stringRegex: NSRegularExpression?

    init(kw: [String] = [], decl: [String] = [], types: [String] = [], selfKw: [String] = [],
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