import AppKit

// MARK: - Highlighter

public enum CodeBlockHighlighter: Sendable {
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

    // MARK: - HTML Regex Patterns

    /// DOCTYPE declaration pattern
    private static let htmlDocRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"<!DOCTYPE[^>]*>"#, options: [.caseInsensitive]
    )

    /// HTML tag names (opening and closing)
    private static let htmlTagRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"</?([a-zA-Z][a-zA-Z0-9]*)[^>]*>"#, options: []
    )

    /// HTML attributes
    private static let htmlAttrRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b([a-zA-Z][-a-zA-Z0-9_]*)\s*="#, options: []
    )

    /// HTML entities
    private static let htmlEntityRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"&(?:#[xX][0-9a-fA-F]+|#\d+|[a-zA-Z]+);"#, options: []
    )

    // MARK: - CSS Regex Patterns

    /// CSS selectors (element.class#id:pseudo)
    private static let cssSelectorRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"[.#]?[a-zA-Z_][a-zA-Z0-9_-]*(?:[.#:][a-zA-Z_][a-zA-Z0-9_-]*)*(?=\s*[,{])"#, options: []
    )

    /// CSS @-rules
    private static let cssAtRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"@[a-zA-Z-]+"#, options: []
    )

    /// CSS properties
    private static let cssPropRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"([a-z][a-z0-9-]*)\s*:"#, options: []
    )

    /// CSS colors (#hex, rgb(), rgba(), hsl(), hsla())
    private static let cssColorRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"#(?:[0-9a-fA-F]{3,8})\b|(?:rgb|rgba|hsl|hsla)\s*\([^)]+\)"#, options: []
    )

    /// CSS numbers with units
    private static let cssNumRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b\d+\.?\d*(?:px|em|rem|%|vh|vw|deg|rad|s|ms|fr|cm|mm|in|pt|pc)?\b"#, options: []
    )

    /// CSS functions (calc(), var(), url(), etc.)
    private static let cssFuncRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\b[a-zA-Z-]+\("#, options: []
    )

    /// CSS variables (--name)
    private static let cssVarRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"--[a-zA-Z_][a-zA-Z0-9_-]*"#, options: []
    )

    public static func highlight(code: String, language: String?, font: NSFont) -> NSAttributedString {
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

        // Use diff highlighter for diff blocks
        if resolvedLang == "diff" {
            return highlightDiffBlock(code: cleanCode, font: font)
        }

        // Use HTML highlighter for HTML blocks
        if resolvedLang == "html" {
            return highlightHTML(code: cleanCode, font: font)
        }

        // Use CSS highlighter for CSS blocks
        if resolvedLang == "css" {
            return highlightCSS(code: cleanCode, font: font)
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

    public static let genericDef = LangDef()

    // MARK: - Language Definitions

    public static let defs: [String: LangDef] = [
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
        CodeBlockTheme.isDark
            ? NSColor(red: 0.35, green: 0.7, blue: 1.0, alpha: 1)   // bright blue
            : NSColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1)
    }
    private static var termExec: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1)    // green
            : NSColor(red: 0.0, green: 0.5, blue: 0.0, alpha: 1)
    }
    private static var termSymlink: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.9, green: 0.5, blue: 0.9, alpha: 1)    // magenta
            : NSColor(red: 0.6, green: 0.0, blue: 0.6, alpha: 1)
    }
    private static var termSize: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.85, green: 0.85, blue: 0.5, alpha: 1)  // yellow
            : NSColor(red: 0.5, green: 0.4, blue: 0.0, alpha: 1)
    }
    private static var termDate: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1)    // dim
            : NSColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
    }
    private static var termPerm: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.6, green: 0.7, blue: 0.6, alpha: 1)    // muted green
            : NSColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1)
    }
    private static var termPath: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 0.4, green: 0.85, blue: 0.85, alpha: 1)  // cyan
            : NSColor(red: 0.0, green: 0.5, blue: 0.5, alpha: 1)
    }
    private static var termError: NSColor {
        CodeBlockTheme.isDark
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
    private static let termWarningRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"\b(?:warning|Warning|WARNING|deprecated|DEPRECATED|caution)\b"#)
    private static var termWarning: NSColor {
        CodeBlockTheme.isDark
            ? NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1)    // yellow
            : NSColor(red: 0.7, green: 0.5, blue: 0.0, alpha: 1)
    }
    private static let termSizeRx: NSRegularExpression? = try? NSRegularExpression(pattern: #"(?<=\s)\d{1,12}(?=\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec))"#)

    // MARK: - Git Output Detection & Highlighting

    private static let gitStatRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\d+ files? changed"#)
    private static let gitInsertRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\d+ insertions?\(\+\)"#)
    private static let gitDeleteRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\d+ deletions?\(-\)"#)
    private static let gitModeRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^\s*(?:delete|create|rename|copy|rewrite)\s+mode\s+\d+"#, options: .anchorsMatchLines)
    private static let gitCommitRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\[[a-zA-Z/\-]+ [0-9a-f]{7,}\]"#)

    private static func looksLikeGitOutput(_ t: String) -> Bool {
        if t.contains("files changed") || t.contains("file changed") { return true }
        if t.hasPrefix("delete mode") || t.hasPrefix("create mode") || t.hasPrefix("rename ") { return true }
        if t.range(of: #"^\[[\w/\-]+ [0-9a-f]{7,}\]"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func highlightGitOutput(line: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: CodeBlockTheme.text
        ])
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        // "N files changed" — yellow
        gitStatRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: termSize, .font: bold], range: mr)
        }
        // "N insertions(+)" — green
        gitInsertRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: termExec, range: mr)
        }
        // "N deletions(-)" — red
        gitDeleteRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: termError, range: mr)
        }
        // "delete mode 100644" / "create mode" — keyword color
        gitModeRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: termDate, range: mr)
        }
        // [main abc1234] — commit ref in cyan bold
        gitCommitRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: termPath, .font: bold], range: mr)
        }
        // File paths in git output → multi-color segments
        actAbsPathRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            let pathStr = ns.substring(with: mr)
            colorizePath(result, pathRange: mr, path: pathStr, bold: bold)
        }
        // Timestamps
        actTimestampRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: termDate, range: mr)
        }

        return result
    }

    // MARK: - Hex Dump Detection & Highlighting

    /// Address portion: "00000000:"
    private static let hexDumpAddrRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"^[0-9a-f]{8}:"#, options: .anchorsMatchLines)
    /// Hex byte groups: 2-4 hex char groups separated by spaces after the address
    private static let hexDumpBytesRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=: )(?:[0-9a-f]{2,4}\s?)+"#, options: .anchorsMatchLines)
    /// ASCII column: the text after two or more spaces following the hex bytes
    private static let hexDumpAsciiRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"  (.+)$"#, options: .anchorsMatchLines)

    // MARK: - D1F Diff Line Highlighting

    /// Highlight a D1F diff line: background stripe for the diff marker, code syntax for the text.
    private static func highlightD1FLine(line: String, font: NSFont) -> NSAttributedString {
        let isDark = CodeBlockTheme.isDark
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Strip emoji prefix to get the code content for syntax highlighting
        let codeContent: String
        if let spaceIdx = trimmed.firstIndex(of: " "), trimmed.distance(from: trimmed.startIndex, to: spaceIdx) <= 2 {
            codeContent = String(trimmed[trimmed.index(after: spaceIdx)...])
        } else {
            codeContent = trimmed
        }

        // Apply code syntax highlighting to the content portion
        // guessLanguage often fails on single lines — default to swift for D1F diffs
        let guessedLang = guessLanguage(from: codeContent) ?? "swift"
        let syntaxHighlighted = highlight(code: codeContent, language: guessedLang, font: font)

        // Build the full line: emoji prefix + syntax-highlighted code
        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: NSColor.labelColor
        ])

        // Find where the code content starts in the original line and overlay syntax colors + bold fonts
        if let contentRange = line.range(of: codeContent) {
            let nsContentRange = NSRange(contentRange, in: line)
            let syntaxRange = NSRange(location: 0, length: syntaxHighlighted.length)
            // Copy foreground colors and font (bold) from syntax highlighter
            syntaxHighlighted.enumerateAttributes(in: syntaxRange) { attrs, range, _ in
                let shifted = NSRange(location: nsContentRange.location + range.location, length: range.length)
                if let color = attrs[.foregroundColor] as? NSColor {
                    result.addAttribute(.foregroundColor, value: color, range: shifted)
                }
                if let attrFont = attrs[.font] as? NSFont {
                    result.addAttribute(.font, value: attrFont, range: shifted)
                }
            }
        }

        // Apply background stripe based on D1F marker
        let bg: NSColor
        if trimmed.hasPrefix("❌ ") {
            bg = isDark
                ? NSColor(red: 0.35, green: 0.08, blue: 0.08, alpha: 1.0)
                : NSColor(red: 0.95, green: 0.80, blue: 0.80, alpha: 1.0)
        } else if trimmed.hasPrefix("✅ ") {
            bg = isDark
                ? NSColor(red: 0.08, green: 0.25, blue: 0.08, alpha: 1.0)
                : NSColor(red: 0.80, green: 0.95, blue: 0.80, alpha: 1.0)
        } else if trimmed.hasPrefix("📎 ") {
            bg = isDark
                ? NSColor(red: 0.10, green: 0.12, blue: 0.19, alpha: 1.0)
                : NSColor(red: 0.87, green: 0.89, blue: 0.95, alpha: 1.0)
        } else {
            bg = .clear
        }

        if bg != .clear {
            result.addAttribute(.backgroundColor, value: bg, range: NSRange(location: 0, length: (line as NSString).length))
        }
        return result
    }

    // MARK: - Hex Dump Detection & Highlighting

    private static func looksLikeHexDump(_ t: String) -> Bool {
        t.range(of: #"^[0-9a-f]{8}: [0-9a-f]{2}"#, options: .regularExpression) != nil
    }

    private static func highlightHexDump(line: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: CodeBlockTheme.text
        ])
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)

        // Address → dim gray
        hexDumpAddrRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: termDate, range: mr)
        }

        // Hex bytes → number color (yellow)
        hexDumpBytesRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: CodeBlockTheme.number, range: mr)
        }

        // ASCII column → cyan
        hexDumpAsciiRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: termPath, range: mr)
        }

        return result
    }

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
        pattern: #"(?:^|\s)(~?\.?/?(?:[\w.@+\-]+/)+[\w.@+\-]+/?)"#, options: .anchorsMatchLines)
    private static let actFlagRx: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<=\s)-{1,2}[\w][\w\-]*"#)

    /// Check if a line is activity log output (timestamps, grep results, or ls output)
    public static func looksLikeActivityLogLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.range(of: #"^\[\d{2}:\d{2}:\d{2}\]"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\S+\.\w+:\d+:"#, options: .regularExpression) != nil { return true }
        if looksLikeHexDump(t) { return true }
        if looksLikeTerminalLine(t) { return true }
        if looksLikeGitOutput(t) { return true }
        if looksLikeD1FLine(t) { return true }
        // Compiler/SPM warnings and errors
        if t.hasPrefix("warning:") || t.hasPrefix("error:") || t.hasPrefix("note:") { return true }
        // Bare file paths (e.g. /Users/... or ~/Documents/...)
        if t.hasPrefix("/") || t.hasPrefix("~/") { return true }
        return false
    }

    /// Check if a line is D1F diff output (📎/❌/✅/📍/📊 prefixed)
    private static func looksLikeD1FLine(_ t: String) -> Bool {
        t.hasPrefix("📎 ") || t.hasPrefix("❌ ") || t.hasPrefix("✅ ") ||
        t.hasPrefix("📍 ") || t.hasPrefix("📊 ") || t.hasPrefix("❓ ")
    }

    /// Check if a single line looks like ls -la output (permissions string)
    private static func looksLikeTerminalLine(_ t: String) -> Bool {
        guard t.count > 10, let first = t.first, "d-lbcps".contains(first) else { return false }
        let perm = t.prefix(10)
        return perm.allSatisfy({ "drwx-lbcpsTt@+. ".contains($0) })
    }

    /// Highlight a single activity log line. Returns nil if the line is not activity-log output.
    public static func highlightActivityLogLine(line: String, font: NSFont) -> NSAttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // D1F diff output (📎/❌/✅ prefixed lines)
        if looksLikeD1FLine(trimmed) {
            return highlightD1FLine(line: line, font: font)
        }

        // Hex dump output (xxd / hexdump)
        if looksLikeHexDump(trimmed) {
            return highlightHexDump(line: line, font: font)
        }

        // Terminal output (ls -la) — use the full terminal highlighter
        if looksLikeTerminalLine(trimmed) {
            return highlightTerminalOutput(code: line, font: font)
        }

        // Git output (files changed, delete mode, commit refs)
        if looksLikeGitOutput(trimmed) {
            return highlightGitOutput(line: line, font: font)
        }

        guard looksLikeActivityLogLine(line) else { return nil }

        let result = NSMutableAttributedString(string: line, attributes: [
            .font: font, .foregroundColor: NSColor.labelColor
        ])
        let ns = line as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        // Paths → multi-color segments (home dim, top-dir green, middle cyan, filename blue bold)
        actAbsPathRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            let pathStr = ns.substring(with: mr)
            colorizePath(result, pathRange: mr, path: pathStr, bold: bold)
        }

        // Grep file:line: → multi-color path, yellow line number
        let cNum = termSize
        actGrepFileRx?.enumerateMatches(in: line, range: r) { m, _, _ in
            guard let m else { return }
            let pathRange = m.range(at: 1)
            let pathStr = ns.substring(with: pathRange)
            colorizePath(result, pathRange: pathRange, path: pathStr, bold: bold)
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

    // MARK: - HTML Highlighting

    /// Highlight HTML code with syntax coloring for tags, attributes, and entities
    private static func highlightHTML(code: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: font, .foregroundColor: CodeBlockTheme.text
        ])
        let ns = code as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        // Theme colors
        let colTag = CodeBlockTheme.keyword
        let colAttr = CodeBlockTheme.prop
        let colString = CodeBlockTheme.string
        let colEntity = CodeBlockTheme.number
        let colComment = CodeBlockTheme.comment

        // Highlight comments first (<!-- ... -->)
        if let commentRx = try? NSRegularExpression(pattern: #"<!--[\s\S]*?-->"#, options: .dotMatchesLineSeparators) {
            commentRx.enumerateMatches(in: code, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                result.addAttribute(.foregroundColor, value: colComment, range: mr)
            }
        }

        // DOCTYPE declarations
        htmlDocRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: colAttr, .font: bold], range: mr)
        }

        // Tag names (opening and closing)
        htmlTagRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttributes([.foregroundColor: colTag, .font: bold], range: mr)
        }

        // Attribute names
        htmlAttrRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: colAttr, range: mr)
        }

        // Strings (attribute values) - override in tag regions
        let htmlStringRx = try? NSRegularExpression(pattern: #""[^"]*""#, options: [])
        htmlStringRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colString, range: mr)
        }

        // HTML entities (&amp;, &#123;, &#x1F600;)
        htmlEntityRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colEntity, range: mr)
        }

        return result
    }

    // MARK: - CSS Highlighting

    /// Highlight CSS code with syntax coloring for selectors, properties, values, and functions
    private static func highlightCSS(code: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: font, .foregroundColor: CodeBlockTheme.text
        ])
        let ns = code as NSString
        let r = NSRange(location: 0, length: ns.length)
        let bold = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)

        // Theme colors
        let colSelector = CodeBlockTheme.keyword
        let colProp = CodeBlockTheme.prop
        let colValue = CodeBlockTheme.string
        let colColor = CodeBlockTheme.number
        let colAt = CodeBlockTheme.preproc
        let colComment = CodeBlockTheme.comment
        let colVar = CodeBlockTheme.selfKw
        let colFunc = CodeBlockTheme.funcCall

        // Highlight comments first (/* ... */)
        if let commentRx = try? NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#, options: .dotMatchesLineSeparators) {
            commentRx.enumerateMatches(in: code, range: r) { m, _, _ in
                guard let mr = m?.range else { return }
                result.addAttribute(.foregroundColor, value: colComment, range: mr)
            }
        }

        // @-rules (@media, @keyframes, @import, etc.)
        cssAtRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: colAt, .font: bold], range: mr)
        }

        // CSS variables (--name)
        cssVarRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colVar, range: mr)
        }

        // Properties (property:)
        cssPropRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range(at: 1) else { return }
            result.addAttribute(.foregroundColor, value: colProp, range: mr)
        }

        // Colors (#hex, rgb(), rgba(), hsl(), hsla())
        cssColorRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colColor, range: mr)
        }

        // Numbers with units
        cssNumRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colColor, range: mr)
        }

        // Functions (calc(), var(), url(), etc.)
        cssFuncRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            let funcNameRange = NSRange(location: mr.location, length: mr.length - 1) // exclude opening paren
            result.addAttribute(.foregroundColor, value: colFunc, range: funcNameRange)
        }

        // Strings
        let cssStringRx = try? NSRegularExpression(pattern: #"'[^']*'|"[^"]*""#, options: [])
        cssStringRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttribute(.foregroundColor, value: colValue, range: mr)
        }

        // Selectors (more complex - apply last)
        cssSelectorRx?.enumerateMatches(in: code, range: r) { m, _, _ in
            guard let mr = m?.range else { return }
            result.addAttributes([.foregroundColor: colSelector, .font: bold], range: mr)
        }

        return result
    }
}
