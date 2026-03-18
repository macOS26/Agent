import AppKit

// MARK: - Code Block Theme (Xcode Dark/Light palette from JibberJabber)

@MainActor enum CodeBlockTheme {
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

    static var keyword: NSColor { c(0xFF7AB2, 0xAD3DA4) }
    static var string: NSColor { c(0xFC6A5D, 0xD12F1B) }
    static var number: NSColor { c(0xD9C97C, 0x272AD8) }
    static var comment: NSColor { c(0x6C9C5A, 0x536579) }
    static var type: NSColor { c(0xD0A8FF, 0x3E8087) }
    static var funcCall: NSColor { c(0x67B7A4, 0x316E74) }
    static var sysFunc: NSColor { c(0xB281EB, 0x6C36A9) }
    static var preproc: NSColor { c(0xFFA14F, 0x78492A) }
    static var attr: NSColor { c(0xFD8F3F, 0x643820) }
    static var prop: NSColor { c(0x4EB0CC, 0x3E8087) }
    static var selfKw: NSColor { c(0xFF7AB2, 0xAD3DA4) }
    static var ident: NSColor { c(0xDFDFE0, 0x000000) }
    static var text: NSColor { c(0xDFDFE0, 0x000000) }
    static var bg: NSColor { c(0x292A30, 0xF0F0F2) }
}

// MARK: - Language Definition

private struct LangDef {
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

// MARK: - Highlighter

@MainActor enum CodeBlockHighlighter {
    private static let wordRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:[a-zA-Z][a-zA-Z0-9_]*|_[a-zA-Z0-9][a-zA-Z0-9_]*)\b"#)
    private static let funcRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*(?=\()"#)
    private static let propRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\.([a-zA-Z_][a-zA-Z0-9_]*)"#)
    private static let numRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)\b"#)
    private static let attrRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"@[a-zA-Z_][a-zA-Z0-9_]*"#)
    private static let prepRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"^\s*#\s*\w+.*$"#, options: .anchorsMatchLines)

    /// Strip ANSI escape sequences from code before highlighting
    private static let ansiRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\x1B\[[0-9;]*[A-Za-z]"#, options: []
    )

    static func highlight(code: String, language: String?, font: NSFont) -> NSAttributedString {
        // Strip any ANSI escape codes so they don't interfere with regex highlighting
        let cleanCode: String
        if let rx = ansiRx {
            cleanCode = rx.stringByReplacingMatches(in: code, range: NSRange(location: 0, length: (code as NSString).length), withTemplate: "")
        } else {
            cleanCode = code
        }

        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        let effectiveLang = language ?? guessLanguage(from: cleanCode)
        let resolvedLang = effectiveLang.map { aliases[$0.lowercased()] ?? $0.lowercased() }

        // Use terminal highlighter for bash/shell output
        if resolvedLang == "bash" && looksLikeTerminalOutput(cleanCode) {
            return highlightTerminalOutput(code: cleanCode, font: font)
        }

        // Pre-capture theme colors for use in @Sendable enumerateMatches closures
        let colText = CodeBlockTheme.text
        let colIdent = CodeBlockTheme.ident
        let colFunc = CodeBlockTheme.funcCall
        let colSysFunc = CodeBlockTheme.sysFunc
        let colProp = CodeBlockTheme.prop
        let colKeyword = CodeBlockTheme.keyword
        let colType = CodeBlockTheme.type
        let colSelfKw = CodeBlockTheme.selfKw
        let colAttr = CodeBlockTheme.attr
        let colPreproc = CodeBlockTheme.preproc
        let colNumber = CodeBlockTheme.number
        let colString = CodeBlockTheme.string
        let colComment = CodeBlockTheme.comment

        let result = NSMutableAttributedString(string: cleanCode, attributes: [
            .font: font, .foregroundColor: colText
        ])
        let def = langDef(for: effectiveLang)
        let ns = cleanCode as NSString
        let r = NSRange(location: 0, length: ns.length)

        // Identifiers
        wordRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
            if let mr = m?.range { result.addAttribute(.foregroundColor, value: colIdent, range: mr) }
        }
        // Function calls
        funcRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
            if let mr = m?.range(at: 1) { result.addAttribute(.foregroundColor, value: colFunc, range: mr) }
        }
        // System functions
        if !def.sysFuncs.isEmpty {
            funcRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                guard let mr = m?.range(at: 1) else { return }
                if def.sysFuncs.contains(ns.substring(with: mr)) {
                    result.addAttribute(.foregroundColor, value: colSysFunc, range: mr)
                }
            }
        }
        // Property access
        propRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
            if let mr = m?.range(at: 1) { result.addAttribute(.foregroundColor, value: colProp, range: mr) }
        }
        // Keywords
        if !def.keywords.isEmpty {
            wordRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                if def.keywords.contains(ns.substring(with: mr)) {
                    result.addAttributes([.foregroundColor: colKeyword, .font: bold], range: mr)
                }
            }
        }
        // Declaration keywords
        if !def.declKeywords.isEmpty {
            wordRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                if def.declKeywords.contains(ns.substring(with: mr)) {
                    result.addAttributes([.foregroundColor: colKeyword, .font: bold], range: mr)
                }
            }
        }
        // Type keywords
        if !def.types.isEmpty {
            wordRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                if def.types.contains(ns.substring(with: mr)) {
                    result.addAttributes([.foregroundColor: colType, .font: bold], range: mr)
                }
            }
        }
        // Self keywords
        if !def.selfKw.isEmpty {
            wordRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                if def.selfKw.contains(ns.substring(with: mr)) {
                    result.addAttribute(.foregroundColor, value: colSelfKw, range: mr)
                }
            }
        }
        // Attributes (@word)
        if def.hasAttrs {
            attrRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                if let mr = m?.range { result.addAttributes([.foregroundColor: colAttr, .font: bold], range: mr) }
            }
        }
        // Preprocessor (#directives)
        if def.hasPreproc {
            prepRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
                if let mr = m?.range { result.addAttribute(.foregroundColor, value: colPreproc, range: mr) }
            }
        }
        // Numbers
        numRx?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
            if let mr = m?.range { result.addAttribute(.foregroundColor, value: colNumber, range: mr) }
        }
        // Strings (override keywords inside strings)
        def.stringRegex?.enumerateMatches(in: cleanCode, range: r) { m, _, _ in
            if let mr = m?.range { result.addAttribute(.foregroundColor, value: colString, range: mr) }
        }
        // Comments (override everything - LAST)
        applyComments(result, code: cleanCode, def: def, range: r, color: colComment)

        return result
    }

    private static func applyComments(_ result: NSMutableAttributedString, code: String, def: LangDef, range: NSRange, color: NSColor) {
        if let start = def.blockComStart, let end = def.blockComEnd {
            let e1 = NSRegularExpression.escapedPattern(for: start)
            let e2 = NSRegularExpression.escapedPattern(for: end)
            if let rx = try? NSRegularExpression(pattern: "\(e1)[\\s\\S]*?\(e2)", options: .dotMatchesLineSeparators) {
                rx.enumerateMatches(in: code, range: range) { m, _, _ in
                    if let r = m?.range { result.addAttribute(.foregroundColor, value: color, range: r) }
                }
            }
        }
        if let prefix = def.commentPrefix {
            let esc = NSRegularExpression.escapedPattern(for: prefix)
            if let rx = try? NSRegularExpression(pattern: "\(esc).*$", options: .anchorsMatchLines) {
                rx.enumerateMatches(in: code, range: range) { m, _, _ in
                    if let r = m?.range { result.addAttribute(.foregroundColor, value: color, range: r) }
                }
            }
        }
    }

    // MARK: - Language Resolution

    private static let aliases: [String: String] = [
        "js": "javascript", "jsx": "javascript", "ts": "typescript", "tsx": "typescript",
        "sh": "bash", "shell": "bash", "zsh": "bash",
        "c++": "cpp", "cc": "cpp", "cxx": "cpp", "h": "c", "hpp": "cpp",
        "objective-c": "objc", "objectivec": "objc", "m": "objc",
        "golang": "go", "rb": "ruby", "rs": "rust", "yml": "yaml",
        "kt": "kotlin", "py": "python", "python3": "python",
    ]

    /// Shell command indicators — if an untagged code block starts with these, use bash highlighting.
    private static let shellPrefixes = ["$", "#", "cd ", "ls ", "cat ", "echo ", "grep ", "find ",
        "git ", "brew ", "sudo ", "mkdir ", "rm ", "cp ", "mv ", "curl ", "chmod ", "chown ",
        "npm ", "pip ", "export ", "source ", "touch ", "tar ", "ssh ", "kill ", "xargs ",
        "xcodebuild ", "swift ", "swiftc ", "clang ", "make ", "docker ", "pkill ",
        "FILTER_BRANCH"]

    private static func langDef(for language: String?) -> LangDef {
        guard let l = language?.lowercased().trimmingCharacters(in: .whitespaces), !l.isEmpty else {
            return genericDef
        }
        let key = aliases[l] ?? l
        return defs[key] ?? genericDef
    }

    /// Guess language from code content when no language tag is provided.
    static func guessLanguage(from code: String) -> String? {
        let firstLine = code.prefix(200).split(separator: "\n").first.map(String.init) ?? code
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        // Shell commands
        if shellPrefixes.contains(where: { trimmed.hasPrefix($0) }) { return "bash" }
        // Swift indicators
        if trimmed.hasPrefix("import ") || trimmed.hasPrefix("func ") || trimmed.hasPrefix("let ")
            || trimmed.hasPrefix("var ") || trimmed.hasPrefix("struct ") || trimmed.hasPrefix("class ")
            || trimmed.hasPrefix("@") || trimmed.hasPrefix("guard ") || trimmed.hasPrefix("enum ")
            || trimmed.hasPrefix("protocol ") { return "swift" }
        // Python
        if trimmed.hasPrefix("def ") || trimmed.hasPrefix("from ") || trimmed.hasPrefix("print(") { return "python" }
        // JSON
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        return nil
    }

    private static let genericDef = LangDef()

    // MARK: - Language Definitions

    private static let defs: [String: LangDef] = [
        "swift": LangDef(
            kw: ["if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
                 "break", "continue", "return", "throw", "do", "try", "catch", "where", "in",
                 "as", "is", "import", "defer", "fallthrough", "some", "any", "async", "await",
                 "throws", "rethrows", "inout"],
            decl: ["func", "let", "var", "class", "struct", "enum", "protocol", "extension",
                   "typealias", "init", "deinit", "subscript", "operator", "associatedtype",
                   "actor", "macro", "public", "private", "internal", "fileprivate", "open",
                   "static", "final", "override", "lazy", "weak", "unowned", "mutating",
                   "nonmutating", "convenience", "required", "dynamic", "indirect",
                   "nonisolated", "consuming", "borrowing", "sending"],
            types: ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
                    "Optional", "Any", "AnyObject", "Void", "Never", "Result", "URL", "Data",
                    "Date", "Error", "Task", "MainActor", "Int8", "Int16", "Int32", "Int64",
                    "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "CGFloat", "NSFont",
                    "NSColor", "NSImage", "NSView", "NSObject", "Character", "Substring"],
            selfKw: ["self", "Self", "super", "true", "false", "nil"],
            sys: ["print", "debugPrint", "dump", "fatalError", "precondition", "assert"],
            attrs: true,
            strPat: #""""[\s\S]*?"""|(#+)"[\s\S]*?"\1|"(?:\\.|[^"\\])*""#
        ),

        "python": LangDef(
            kw: ["if", "elif", "else", "for", "while", "break", "continue", "return", "pass",
                 "raise", "try", "except", "finally", "with", "as", "import", "from", "yield",
                 "assert", "del", "in", "not", "and", "or", "is", "lambda", "async", "await",
                 "match", "case"],
            decl: ["def", "class", "global", "nonlocal"],
            types: ["int", "float", "str", "bool", "list", "dict", "tuple", "set", "bytes",
                    "range", "type", "object", "Exception", "complex", "frozenset"],
            selfKw: ["self", "cls", "True", "False", "None"],
            sys: ["print", "len", "range", "enumerate", "zip", "map", "filter", "sorted",
                  "reversed", "isinstance", "hasattr", "getattr", "super", "open", "input"],
            comment: "#", blockStart: nil, blockEnd: nil,
            strPat: #""""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#
        ),

        "javascript": LangDef(
            kw: ["if", "else", "for", "while", "do", "break", "continue", "return", "throw",
                 "try", "catch", "finally", "switch", "case", "default", "new", "delete",
                 "typeof", "instanceof", "in", "of", "void", "yield", "async", "await",
                 "import", "export", "from", "as"],
            decl: ["function", "const", "let", "var", "class", "extends", "static", "get", "set"],
            types: ["Array", "Object", "String", "Number", "Boolean", "Symbol", "BigInt",
                    "Map", "Set", "Promise", "RegExp", "Error", "Date", "JSON", "Math"],
            selfKw: ["this", "super", "true", "false", "null", "undefined", "NaN", "Infinity"],
            sys: ["console", "setTimeout", "setInterval", "fetch", "require"],
            strPat: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#
        ),

        "typescript": LangDef(
            kw: ["if", "else", "for", "while", "do", "break", "continue", "return", "throw",
                 "try", "catch", "finally", "switch", "case", "default", "new", "delete",
                 "typeof", "instanceof", "in", "of", "void", "yield", "async", "await",
                 "import", "export", "from", "as", "keyof", "readonly", "satisfies"],
            decl: ["function", "const", "let", "var", "class", "interface", "type", "enum",
                   "namespace", "module", "declare", "abstract", "implements", "static",
                   "get", "set", "public", "private", "protected", "extends"],
            types: ["string", "number", "boolean", "symbol", "bigint", "any", "unknown",
                    "never", "void", "undefined", "null", "Array", "Object", "Map", "Set",
                    "Promise", "Record", "Partial", "Required", "Readonly", "Pick", "Omit"],
            selfKw: ["this", "super", "true", "false", "null", "undefined"],
            sys: ["console", "setTimeout", "setInterval", "fetch", "require"],
            strPat: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#
        ),

        "bash": LangDef(
            kw: ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
                 "esac", "in", "until", "select", "break", "continue", "return", "exit"],
            decl: ["function", "local", "export", "declare", "typeset", "readonly", "source"],
            selfKw: ["true", "false"],
            sys: ["echo", "printf", "cd", "ls", "cat", "grep", "sed", "awk", "find", "sort",
                  "head", "tail", "wc", "chmod", "chown", "mkdir", "rm", "cp", "mv", "curl",
                  "wget", "git", "npm", "pip", "brew", "sudo", "eval", "exec", "test",
                  "read", "set", "unset", "trap", "xargs", "tar", "ssh", "kill", "touch",
                  "swift", "swiftc", "xcodebuild", "xcrun", "clang", "make", "docker",
                  "pkill", "launchctl", "defaults", "open", "pbcopy", "pbpaste", "which",
                  "env", "basename", "dirname", "date", "diff", "patch", "tee", "uname"],
            comment: "#", blockStart: nil, blockEnd: nil,
            strPat: #""(?:\\.|[^"\\])*"|'[^']*'"#
        ),

        "c": LangDef(
            kw: ["if", "else", "for", "while", "do", "switch", "case", "default", "break",
                 "continue", "return", "goto", "sizeof"],
            decl: ["typedef", "struct", "union", "enum", "extern", "static", "const",
                   "volatile", "register", "auto", "inline", "restrict"],
            types: ["void", "char", "short", "int", "long", "float", "double", "signed",
                    "unsigned", "size_t", "int8_t", "int16_t", "int32_t", "int64_t",
                    "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool", "FILE"],
            selfKw: ["NULL", "true", "false"],
            sys: ["printf", "fprintf", "sprintf", "scanf", "malloc", "calloc", "realloc",
                  "free", "memcpy", "memset", "strlen", "strcmp", "fopen", "fclose", "exit"],
            preproc: true
        ),

        "cpp": LangDef(
            kw: ["if", "else", "for", "while", "do", "switch", "case", "default", "break",
                 "continue", "return", "goto", "sizeof", "throw", "try", "catch", "new",
                 "delete", "noexcept", "co_await", "co_yield", "co_return", "requires"],
            decl: ["typedef", "struct", "union", "enum", "class", "namespace", "using",
                   "template", "typename", "virtual", "override", "final", "public",
                   "private", "protected", "extern", "static", "const", "volatile",
                   "inline", "constexpr", "explicit", "friend", "mutable", "operator",
                   "auto", "decltype", "concept"],
            types: ["void", "char", "short", "int", "long", "float", "double", "signed",
                    "unsigned", "bool", "string", "vector", "map", "set", "unordered_map",
                    "unordered_set", "pair", "tuple", "shared_ptr", "unique_ptr",
                    "optional", "variant", "any", "array", "size_t"],
            selfKw: ["this", "nullptr", "true", "false", "NULL"],
            sys: ["std", "cout", "cin", "cerr", "endl", "printf", "scanf"],
            preproc: true
        ),

        "go": LangDef(
            kw: ["if", "else", "for", "range", "switch", "case", "default", "break",
                 "continue", "return", "goto", "fallthrough", "defer", "go", "select", "chan"],
            decl: ["func", "var", "const", "type", "struct", "interface", "map",
                   "package", "import"],
            types: ["string", "int", "int8", "int16", "int32", "int64", "uint", "uint8",
                    "uint16", "uint32", "uint64", "float32", "float64", "byte", "rune",
                    "bool", "error", "any", "comparable"],
            selfKw: ["true", "false", "nil", "iota"],
            sys: ["fmt", "make", "new", "len", "cap", "append", "copy", "delete", "close",
                  "panic", "recover", "print", "println"],
            strPat: #""(?:\\.|[^"\\])*"|`[^`]*`"#
        ),

        "objc": LangDef(
            kw: ["if", "else", "for", "while", "do", "switch", "case", "default", "break",
                 "continue", "return", "goto", "sizeof", "in"],
            decl: ["typedef", "struct", "union", "enum", "extern", "static", "const",
                   "volatile", "auto", "inline", "@interface", "@implementation", "@end",
                   "@protocol", "@property", "@synthesize", "@dynamic", "@class",
                   "@autoreleasepool", "@try", "@catch", "@finally", "@throw", "@selector"],
            types: ["void", "char", "short", "int", "long", "float", "double", "signed",
                    "unsigned", "BOOL", "id", "instancetype", "NSObject", "NSString",
                    "NSArray", "NSDictionary", "NSNumber", "NSInteger", "NSUInteger",
                    "CGFloat", "CGRect", "CGPoint", "CGSize", "SEL", "Class"],
            selfKw: ["self", "super", "nil", "Nil", "NULL", "YES", "NO", "true", "false"],
            sys: ["NSLog", "alloc", "init", "dealloc"],
            preproc: true,
            strPat: #"@?"(?:\\.|[^"\\])*""#
        ),

        "rust": LangDef(
            kw: ["if", "else", "for", "while", "loop", "break", "continue", "return",
                 "match", "in", "as", "ref", "move", "yield", "async", "await", "unsafe", "where"],
            decl: ["fn", "let", "mut", "const", "static", "struct", "enum", "trait", "impl",
                   "type", "mod", "use", "pub", "crate", "extern", "dyn", "macro_rules"],
            types: ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
                    "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec",
                    "Box", "Rc", "Arc", "Option", "Result", "HashMap", "HashSet"],
            selfKw: ["self", "Self", "super", "crate", "true", "false"],
            sys: ["println", "print", "eprintln", "format", "vec", "todo", "panic",
                  "assert", "assert_eq", "dbg"],
            attrs: true
        ),

        "ruby": LangDef(
            kw: ["if", "elsif", "else", "unless", "case", "when", "while", "until", "for",
                 "do", "break", "next", "return", "redo", "retry", "begin", "rescue",
                 "ensure", "raise", "end", "then", "yield", "in", "and", "or", "not"],
            decl: ["def", "class", "module", "attr_accessor", "attr_reader", "attr_writer",
                   "include", "extend", "require", "require_relative", "public", "private",
                   "protected"],
            types: ["String", "Integer", "Float", "Array", "Hash", "Symbol", "Proc",
                    "Regexp", "Range", "IO", "File", "NilClass", "TrueClass", "FalseClass"],
            selfKw: ["self", "super", "true", "false", "nil"],
            sys: ["puts", "print", "p", "gets", "each", "map", "select", "reduce"],
            comment: "#", blockStart: nil, blockEnd: nil,
            strPat: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#
        ),

        "java": LangDef(
            kw: ["if", "else", "for", "while", "do", "switch", "case", "default", "break",
                 "continue", "return", "throw", "try", "catch", "finally", "new",
                 "instanceof", "assert", "synchronized", "throws"],
            decl: ["class", "interface", "enum", "extends", "implements", "abstract", "final",
                   "static", "public", "private", "protected", "package", "import", "native",
                   "volatile", "transient", "record", "sealed", "var"],
            types: ["void", "boolean", "byte", "char", "short", "int", "long", "float",
                    "double", "String", "Object", "Integer", "Long", "Double", "Float",
                    "Boolean", "List", "Map", "Set", "ArrayList", "HashMap", "Optional"],
            selfKw: ["this", "super", "true", "false", "null"],
            sys: ["System", "println", "printf", "Math"],
            attrs: true
        ),

        "kotlin": LangDef(
            kw: ["if", "else", "for", "while", "do", "when", "break", "continue", "return",
                 "throw", "try", "catch", "finally", "in", "is", "as", "by", "where",
                 "suspend", "inline", "crossinline", "noinline", "reified"],
            decl: ["fun", "val", "var", "class", "interface", "object", "enum", "sealed",
                   "data", "abstract", "open", "override", "final", "companion", "inner",
                   "import", "package", "typealias", "constructor", "init", "get", "set",
                   "public", "private", "protected", "internal", "lateinit", "const"],
            types: ["String", "Int", "Long", "Short", "Byte", "Float", "Double", "Boolean",
                    "Char", "Unit", "Nothing", "Any", "Array", "List", "MutableList", "Map",
                    "MutableMap", "Set", "MutableSet", "Pair", "Triple", "Sequence"],
            selfKw: ["this", "super", "true", "false", "null"],
            sys: ["println", "print", "require", "check", "error", "listOf", "mapOf", "setOf"],
            attrs: true,
            strPat: #""""[\s\S]*?"""|"(?:\\.|[^"\\])*""#
        ),

        "json": LangDef(
            selfKw: ["true", "false", "null"],
            comment: nil, blockStart: nil, blockEnd: nil
        ),

        "yaml": LangDef(
            selfKw: ["true", "false", "null", "yes", "no", "on", "off"],
            comment: "#", blockStart: nil, blockEnd: nil,
            strPat: #""(?:\\.|[^"\\])*"|'[^']*'"#
        ),

        "sql": LangDef(
            kw: ["SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "BETWEEN", "LIKE",
                 "IS", "NULL", "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET", "UNION",
                 "ALL", "DISTINCT", "AS", "ON", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
                 "CROSS", "FULL", "CASE", "WHEN", "THEN", "ELSE", "END", "EXISTS",
                 "select", "from", "where", "and", "or", "not", "in", "between", "like",
                 "is", "null", "order", "by", "group", "having", "limit", "offset", "union",
                 "all", "distinct", "as", "on", "join", "left", "right", "inner", "outer",
                 "cross", "full", "case", "when", "then", "else", "end", "exists"],
            decl: ["CREATE", "ALTER", "DROP", "INSERT", "UPDATE", "DELETE", "INTO", "VALUES",
                   "SET", "TABLE", "INDEX", "VIEW", "DATABASE", "PRIMARY", "KEY", "FOREIGN",
                   "REFERENCES", "UNIQUE", "DEFAULT", "CONSTRAINT",
                   "create", "alter", "drop", "insert", "update", "delete", "into", "values",
                   "set", "table", "index", "view", "database", "primary", "key", "foreign",
                   "references", "unique", "default", "constraint"],
            types: ["INTEGER", "INT", "BIGINT", "SMALLINT", "DECIMAL", "FLOAT", "REAL",
                    "VARCHAR", "CHAR", "TEXT", "BLOB", "DATE", "TIMESTAMP", "BOOLEAN",
                    "integer", "int", "bigint", "smallint", "decimal", "float", "real",
                    "varchar", "char", "text", "blob", "date", "timestamp", "boolean"],
            selfKw: ["TRUE", "FALSE", "NULL", "true", "false", "null"],
            comment: "--",
            strPat: "'(?:''|[^'])*'"
        ),

        "html": LangDef(comment: nil, blockStart: "<!--", blockEnd: "-->",
                         strPat: #""[^"]*"|'[^']*'"#),
        "xml": LangDef(comment: nil, blockStart: "<!--", blockEnd: "-->",
                        strPat: #""[^"]*"|'[^']*'"#),
        "css": LangDef(comment: nil, blockStart: "/*", blockEnd: "*/",
                        strPat: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#),
    ]

    // MARK: - Terminal Output Detection & Highlighting

    /// Detect if bash block is command output (ls, ps, etc.) vs a shell script.
    private static func looksLikeTerminalOutput(_ code: String) -> Bool {
        let lines = code.split(separator: "\n", maxSplits: 5, omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return false }
        var outputIndicators = 0
        for line in lines.prefix(5) {
            let t = line.trimmingCharacters(in: .whitespaces)
            // ls -la style: permissions string
            if t.count > 10, let first = t.first, "d-lbcps".contains(first) {
                let perm = t.prefix(10)
                if perm.allSatisfy({ "drwx-lbcpsTt@+. ".contains($0) }) { outputIndicators += 2 }
            }
            // "total N" line from ls
            if t.hasPrefix("total ") && t.dropFirst(6).allSatisfy({ $0.isNumber }) { outputIndicators += 2 }
            // Lines starting with / (paths)
            if t.hasPrefix("/") { outputIndicators += 1 }
            // Numeric-heavy lines (ps, df, etc.)
            let digits = t.filter(\.isNumber).count
            if t.count > 10 && Double(digits) / Double(t.count) > 0.3 { outputIndicators += 1 }
        }
        return outputIndicators >= 2
    }

    // Terminal output theme colors
    private static var termDir: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 1)   // bright blue
            : NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1)
    }
    private static var termExec: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1)    // green
            : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1)
    }
    private static var termSymlink: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.9, green: 0.5, blue: 0.9, alpha: 1)    // magenta
            : NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1)
    }
    private static var termSize: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.85, green: 0.85, blue: 0.5, alpha: 1)  // yellow
            : NSColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 1)
    }
    private static var termDate: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1)    // dim
            : NSColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
    }
    private static var termPerm: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.6, green: 0.7, blue: 0.6, alpha: 1)    // muted green
            : NSColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1)
    }
    private static var termPath: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.4, green: 0.85, blue: 0.85, alpha: 1)  // cyan
            : NSColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1)
    }
    private static var termError: NSColor {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1)    // red
            : NSColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1)
    }

    // Precompiled regexes for terminal output
    private static let termPermRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"^[d\-lbcps][rwxstTSl\-]{9}[.@+\s]?"#, options: .anchorsMatchLines)
    private static let termTotalRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"^total\s+\d+"#, options: .anchorsMatchLines)
    private static let termDateRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+(?:\d{4}|\d{1,2}:\d{2})"#)
    private static let termPathRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?:^|\s)((?:/[\w.\-@]+)+/?)"#, options: .anchorsMatchLines)
    private static let termArrowRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\s->\s.*$"#, options: .anchorsMatchLines)
    private static let termErrorRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:error|Error|ERROR|fatal|FATAL|failed|FAILED|No such file|Permission denied|not found|cannot)\b"#)
    private static let termSizeRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?<=\s)\d{1,12}(?=\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))"#)

    // MARK: - Activity Log Line Highlighting

    private static let actTimestampRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\[\d{2}:\d{2}:\d{2}\]"#)
    private static let actSectionRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"---\s+.+?\s+---"#)
    private static let actLabelRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b(?:Task|Model|Status|Error|Warning|Result|Info|Read|exit code):"#)
    private static let actShellRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\$\s+\S+"#)
    private static let actPipeCmdRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:&&|\|)\s+(\w+)"#)
    private static let actGrepFileRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^([^\s:]+):(\d+):"#, options: .anchorsMatchLines)
    private static let actAbsPathRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?:^|\s)(\.?/?(?:[\w.@+\-]+/)+[\w.@+\-]+/?)"#, options: .anchorsMatchLines)
    private static let actFlagRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\s)-{1,2}[\w][\w\-]*"#)
    private static let actQuoteRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: ##"'[^'\n]*'|"[^"\n]*""##)

    /// Check if a line is activity log output (timestamps or grep results)
    static func looksLikeActivityLogLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.range(of: #"^\[\d{2}:\d{2}:\d{2}\]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\S+\.\w+:\d+:"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Highlight a single activity log line. Returns nil if the line is not activity-log output.
    static func highlightActivityLogLine(line: String, font: NSFont) -> NSAttributedString? {
        guard looksLikeActivityLogLine(line) else { return nil }

        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: NSColor.labelColor
        ])
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        // Paths → cyan
        let cPath = termPath
        actAbsPathRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: cPath, range: mr)
        }

        // Grep file:line: → cyan path, yellow line number
        let cNum = termSize
        actGrepFileRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let m else { return }
            result.addAttribute(.foregroundColor, value: cPath, range: m.range(at: 1))
            result.addAttribute(.foregroundColor, value: cNum, range: m.range(at: 2))
        }

        // Shell $ command → green
        let cCmd = termExec
        actShellRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: cCmd, range: mr)
        }

        // Pipe/chain commands (| grep, && grep) → green
        actPipeCmdRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: cCmd, range: mr)
        }

        // Flags --option → orange
        let cFlag = CodeBlockTheme.preproc
        actFlagRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: cFlag, range: mr)
        }

        // Quoted strings → string color
        let cStr = CodeBlockTheme.string
        actQuoteRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: cStr, range: mr)
        }

        // Timestamps [HH:MM:SS] → dim
        let cTime = termDate
        actTimestampRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: cTime, range: mr)
        }

        // Section headers --- text --- → bold keyword
        let cKw = CodeBlockTheme.keyword
        actSectionRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: cKw, .font: bold], range: mr)
        }

        // Labels Task:, Model: → bold keyword
        actLabelRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: cKw, .font: bold], range: mr)
        }

        // Error keywords → red (last, overrides other colors)
        let cErr = termError
        termErrorRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: cErr, range: mr)
        }

        return result
    }

    private static func highlightTerminalOutput(code: String, font: NSFont) -> NSAttributedString {
        let text = CodeBlockTheme.text
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: font, .foregroundColor: text
        ])
        let ns = code as NSString
        let r = NSRange(location: 0, length: ns.length)

        // Permissions (drwxr-xr-x)
        let colPerm = termPerm
        termPermRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colPerm, range: mr)
        }

        // "total N"
        let colDate = termDate
        termTotalRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colDate, range: mr)
        }

        // File sizes (number before date)
        let colSize = termSize
        termSizeRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colSize, range: mr)
        }

        // Dates
        termDateRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colDate, range: mr)
        }

        // Paths (/usr/bin/...)
        let colPath = termPath
        termPathRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: colPath, range: mr)
        }

        // Symlink arrows (-> target)
        let colSym = termSymlink
        termArrowRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colSym, range: mr)
        }

        // Error keywords
        let colErr = termError
        termErrorRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colErr, range: mr)
        }

        // Color filenames at end of ls lines — directories blue, executables green
        let lines = code.components(separatedBy: "\n")
        var lineStart = 0
        let colDir = termDir
        let colExec = termExec
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
        for line in lines {
            let lineLen = (line as NSString).length
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect ls -la lines by permissions pattern
            if trimmed.count > 10 {
                let first = trimmed.first ?? " "
                if "d-lbcps".contains(first) {
                    let perm = String(trimmed.prefix(10))
                    if perm.allSatisfy({ "drwx-lbcpsTt@+. ".contains($0) }) {
                        // Find filename after the date (last component)
                        guard let dateRx = try? NSRegularExpression(pattern: #"(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}\s+(?:\d{4}|\d{1,2}:\d{2})\s+"#) else { continue }
                        if let dateMatch = dateRx.firstMatch(in: line, range: NSRange(location: 0, length: lineLen)) {
                            let nameStart = dateMatch.range.location + dateMatch.range.length
                            if nameStart < lineLen {
                                let nameRange = NSRange(location: lineStart + nameStart, length: lineLen - nameStart)
                                if first == "d" {
                                    result.addAttributes([.foregroundColor: colDir, .font: bold], range: nameRange)
                                } else if first == "l" {
                                    result.addAttribute(.foregroundColor, value: colSym, range: nameRange)
                                } else if perm.contains("x") {
                                    result.addAttribute(.foregroundColor, value: colExec, range: nameRange)
                                }
                            }
                        }
                    }
                }
            }
            lineStart += lineLen + 1 // +1 for \n
        }

        return result
    }
}
