import AppKit

enum Language: String {
    case swift
    case javascript
    case typescript
    case python
    case rust
    case go
    case java
    case kotlin
    case cLike
    case ruby
    case php
    case html
    case css
    case json
    case markdown
    case shell
    case yaml
    case sql
    case plain

    var displayName: String {
        switch self {
        case .swift: "Swift"
        case .javascript: "JavaScript"
        case .typescript: "TypeScript"
        case .python: "Python"
        case .rust: "Rust"
        case .go: "Go"
        case .java: "Java"
        case .kotlin: "Kotlin"
        case .cLike: "C / C++ / C#"
        case .ruby: "Ruby"
        case .php: "PHP"
        case .html: "HTML / XML"
        case .css: "CSS"
        case .json: "JSON"
        case .markdown: "Markdown"
        case .shell: "Shell"
        case .yaml: "YAML"
        case .sql: "SQL"
        case .plain: "Plain Text"
        }
    }

    var fenceIdentifier: String {
        switch self {
        case .swift: "swift"
        case .javascript: "javascript"
        case .typescript: "typescript"
        case .python: "python"
        case .rust: "rust"
        case .go: "go"
        case .java: "java"
        case .kotlin: "kotlin"
        case .cLike: "c"
        case .ruby: "ruby"
        case .php: "php"
        case .html: "html"
        case .css: "css"
        case .json: "json"
        case .markdown: "markdown"
        case .shell: "bash"
        case .yaml: "yaml"
        case .sql: "sql"
        case .plain: ""
        }
    }

    static func detect(from url: URL) -> Language {
        switch url.pathExtension.lowercased() {
        case "swift": .swift
        case "js", "jsx", "mjs", "cjs": .javascript
        case "ts", "tsx": .typescript
        case "py", "pyw": .python
        case "rs": .rust
        case "go": .go
        case "java": .java
        case "kt", "kts": .kotlin
        case "c", "h", "m", "mm", "cc", "cpp", "cxx", "hpp", "cs": .cLike
        case "rb": .ruby
        case "php": .php
        case "html", "htm", "xml", "xhtml", "svg": .html
        case "css", "scss", "sass", "less": .css
        case "json", "jsonc": .json
        case "md", "markdown": .markdown
        case "sh", "bash", "zsh", "fish": .shell
        case "yml", "yaml": .yaml
        case "sql": .sql
        default:
            switch url.lastPathComponent.lowercased() {
            case "package.resolved", "package.json", "composer.json", "tsconfig.json": .json
            case "dockerfile", "makefile", ".zshrc", ".bashrc": .shell
            default: .plain
            }
        }
    }
}

final class SyntaxHighlighter: @unchecked Sendable {
    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    private let boldFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)

    private let baseColor = CodeLightTheme.textPrimary
    private let keywordColor = CodeLightTheme.syntaxKeyword
    private let stringColor = CodeLightTheme.syntaxString
    private let numberColor = CodeLightTheme.syntaxNumber
    private let commentColor = CodeLightTheme.syntaxComment
    private let tagColor = CodeLightTheme.syntaxTag
    private let attributeColor = CodeLightTheme.syntaxAttribute

    func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: baseAttributes)
    }

    func highlight(_ text: String, as language: Language) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        let fullRange = NSRange(location: 0, length: attributed.length)

        switch language {
        case .html:
            highlightHTML(attributed, fullRange: fullRange)
        case .css:
            highlightCSS(attributed, fullRange: fullRange)
        case .json:
            highlightJSON(attributed, fullRange: fullRange)
        case .markdown:
            highlightMarkdown(attributed, fullRange: fullRange)
        case .yaml:
            highlightYAML(attributed, fullRange: fullRange)
        case .sql:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.sqlKeywords,
                singleLineComment: "--",
                multiLineComments: [("/*", "*/")]
            )
        case .shell:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.shellKeywords,
                singleLineComment: "#",
                multiLineComments: []
            )
        case .python:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.pythonKeywords,
                singleLineComment: "#",
                multiLineComments: [("\"\"\"", "\"\"\""), ("'''", "'''")]
            )
        case .ruby:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.rubyKeywords,
                singleLineComment: "#",
                multiLineComments: []
            )
        case .swift:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.swiftKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .javascript:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.javascriptKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .typescript:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.typescriptKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .rust:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.rustKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .go:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.goKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .java:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.javaKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .kotlin:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.kotlinKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .cLike:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.cLikeKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
        case .php:
            highlightGeneric(
                attributed,
                fullRange: fullRange,
                keywords: Self.phpKeywords,
                singleLineComment: "//",
                multiLineComments: [("/*", "*/")]
            )
            apply(pattern: #"(?m)#.*$"#, to: attributed, color: commentColor, range: fullRange)
        case .plain:
            break
        }

        return attributed
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]
    }

    private var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byClipping
        style.defaultTabInterval = 32
        style.tabStops = []
        return style
    }

    private func highlightGeneric(
        _ attributed: NSMutableAttributedString,
        fullRange: NSRange,
        keywords: Set<String>,
        singleLineComment: String,
        multiLineComments: [(String, String)]
    ) {
        highlightStrings(attributed, fullRange: fullRange)
        apply(pattern: #"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, to: attributed, color: numberColor, range: fullRange)
        applyKeywords(keywords, to: attributed, range: fullRange)

        if !singleLineComment.isEmpty {
            let escaped = NSRegularExpression.escapedPattern(for: singleLineComment)
            apply(pattern: "(?m)\(escaped).*?$", to: attributed, color: commentColor, range: fullRange)
        }

        for pair in multiLineComments {
            let start = NSRegularExpression.escapedPattern(for: pair.0)
            let end = NSRegularExpression.escapedPattern(for: pair.1)
            apply(pattern: "\(start)[\\s\\S]*?\(end)", to: attributed, color: commentColor, range: fullRange)
        }
    }

    private func highlightStrings(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, to: attributed, color: stringColor, range: fullRange)
    }

    private func highlightHTML(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #"<!--[\s\S]*?-->"#, to: attributed, color: commentColor, range: fullRange)
        apply(pattern: #"</?[A-Za-z][\w:.-]*"#, to: attributed, color: tagColor, range: fullRange, font: boldFont)
        apply(pattern: #"\s[A-Za-z_:][-A-Za-z0-9_:.]*(?=\=)"#, to: attributed, color: attributeColor, range: fullRange)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: attributed, color: stringColor, range: fullRange)
        apply(pattern: #"[<>/]"#, to: attributed, color: secondaryTagColor, range: fullRange)
    }

    private func highlightCSS(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #"/\*[\s\S]*?\*/"#, to: attributed, color: commentColor, range: fullRange)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: attributed, color: stringColor, range: fullRange)
        apply(pattern: #"\b\d+(?:\.\d+)?(?:px|rem|em|vh|vw|%|s|ms|deg)?\b"#, to: attributed, color: numberColor, range: fullRange)
        apply(pattern: #"#[0-9A-Fa-f]{3,8}\b"#, to: attributed, color: numberColor, range: fullRange)
        apply(pattern: #"(?m)^\s*[^{}\n]+(?=\s*\{)"#, to: attributed, color: tagColor, range: fullRange, font: boldFont)
        apply(pattern: #"[A-Za-z-]+(?=\s*:)"#, to: attributed, color: attributeColor, range: fullRange)
    }

    private func highlightJSON(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#, to: attributed, color: attributeColor, range: fullRange)
        apply(pattern: #""(?:\\.|[^"\\])*""#, to: attributed, color: stringColor, range: fullRange)
        apply(pattern: #"\b(?:true|false|null)\b"#, to: attributed, color: keywordColor, range: fullRange, font: boldFont)
        apply(pattern: #"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, to: attributed, color: numberColor, range: fullRange)
    }

    private func highlightMarkdown(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #"(?m)^#{1,6}\s.*$"#, to: attributed, color: tagColor, range: fullRange, font: boldFont)
        apply(pattern: #"(?m)^\s*[-*+]\s+"#, to: attributed, color: keywordColor, range: fullRange, font: boldFont)
        apply(pattern: #"`[^`]+`"#, to: attributed, color: stringColor, range: fullRange)
        apply(pattern: #"\[[^\]]+\]\([^)]+\)"#, to: attributed, color: attributeColor, range: fullRange)
        apply(pattern: #"(?m)^>\s.*$"#, to: attributed, color: commentColor, range: fullRange)
    }

    private func highlightYAML(_ attributed: NSMutableAttributedString, fullRange: NSRange) {
        apply(pattern: #"(?m)#.*$"#, to: attributed, color: commentColor, range: fullRange)
        apply(pattern: #"(?m)^\s*[-]?\s*[\w.-]+(?=\s*:)"#, to: attributed, color: attributeColor, range: fullRange, font: boldFont)
        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, to: attributed, color: stringColor, range: fullRange)
        apply(pattern: #"\b(?:true|false|null|yes|no|on|off)\b"#, to: attributed, color: keywordColor, range: fullRange)
        apply(pattern: #"\b\d+(?:\.\d+)?\b"#, to: attributed, color: numberColor, range: fullRange)
    }

    private func applyKeywords(
        _ keywords: Set<String>,
        to attributed: NSMutableAttributedString,
        range: NSRange
    ) {
        guard !keywords.isEmpty else { return }
        let escaped = keywords
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        apply(pattern: "\\b(?:\(escaped))\\b", to: attributed, color: keywordColor, range: range, font: boldFont)
    }

    private func apply(
        pattern: String,
        to attributed: NSMutableAttributedString,
        color: NSColor,
        range: NSRange,
        font: NSFont? = nil
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        regex.enumerateMatches(in: attributed.string, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range, matchRange.location != NSNotFound else { return }
            attributed.addAttribute(.foregroundColor, value: color, range: matchRange)
            if let font {
                attributed.addAttribute(.font, value: font, range: matchRange)
            }
        }
    }

    private var secondaryTagColor: NSColor {
        tagColor.withAlphaComponent(0.72)
    }

    private static let swiftKeywords: Set<String> = [
        "actor", "as", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue",
        "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "false", "fileprivate",
        "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is", "let", "nil", "open",
        "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "self", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var", "where", "while"
    ]

    private static let javascriptKeywords: Set<String> = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
        "do", "else", "export", "extends", "false", "finally", "for", "from", "function", "get", "if", "import",
        "in", "instanceof", "let", "new", "null", "of", "return", "set", "static", "super", "switch", "this",
        "throw", "true", "try", "typeof", "undefined", "var", "void", "while", "yield"
    ]

    private static let typescriptKeywords: Set<String> = javascriptKeywords.union([
        "abstract", "any", "as", "boolean", "declare", "enum", "implements", "interface", "keyof", "namespace",
        "never", "number", "private", "protected", "public", "readonly", "string", "type", "unknown"
    ])

    private static let pythonKeywords: Set<String> = [
        "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
        "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is",
        "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"
    ]

    private static let rustKeywords: Set<String> = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum", "extern", "false",
        "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
        "self", "Self", "static", "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while"
    ]

    private static let goKeywords: Set<String> = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func",
        "go", "goto", "if", "import", "interface", "map", "nil", "package", "range", "return", "select", "struct",
        "switch", "type", "var", "true", "false", "iota"
    ]

    private static let javaKeywords: Set<String> = [
        "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const", "continue",
        "default", "do", "double", "else", "enum", "extends", "false", "final", "finally", "float", "for", "if",
        "implements", "import", "instanceof", "int", "interface", "long", "native", "new", "null", "package",
        "private", "protected", "public", "return", "short", "static", "strictfp", "super", "switch",
        "synchronized", "this", "throw", "throws", "transient", "true", "try", "void", "volatile", "while"
    ]

    private static let kotlinKeywords: Set<String> = [
        "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in", "interface", "is",
        "null", "object", "package", "return", "super", "this", "throw", "true", "try", "typealias", "typeof",
        "val", "var", "when", "while", "by", "catch", "constructor", "delegate", "dynamic", "field", "file",
        "finally", "get", "import", "init", "param", "property", "receiver", "set", "setparam", "where"
    ]

    private static let cLikeKeywords: Set<String> = [
        "auto", "bool", "break", "case", "catch", "char", "class", "const", "constexpr", "continue", "default",
        "delete", "do", "double", "else", "enum", "explicit", "extern", "false", "float", "for", "friend", "goto",
        "if", "inline", "int", "long", "namespace", "new", "nullptr", "private", "protected", "public", "return",
        "short", "signed", "sizeof", "static", "struct", "switch", "template", "this", "throw", "true", "try",
        "typedef", "typename", "union", "unsigned", "using", "virtual", "void", "volatile", "while"
    ]

    private static let rubyKeywords: Set<String> = [
        "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def", "defined", "do", "else",
        "elsif", "end", "ensure", "false", "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
        "rescue", "retry", "return", "self", "super", "then", "true", "undef", "unless", "until", "when", "while",
        "yield"
    ]

    private static let phpKeywords: Set<String> = [
        "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class", "clone", "const",
        "continue", "declare", "default", "die", "do", "echo", "else", "elseif", "empty", "enddeclare", "endfor",
        "endforeach", "endif", "endswitch", "endwhile", "eval", "exit", "extends", "final", "finally", "fn",
        "for", "foreach", "function", "global", "goto", "if", "implements", "include", "include_once", "instanceof",
        "interface", "isset", "list", "namespace", "new", "or", "print", "private", "protected", "public", "require",
        "require_once", "return", "static", "switch", "throw", "trait", "try", "unset", "use", "var", "while", "xor"
    ]

    private static let shellKeywords: Set<String> = [
        "case", "do", "done", "elif", "else", "esac", "export", "fi", "for", "function", "if", "in", "local",
        "readonly", "return", "select", "shift", "then", "until", "while"
    ]

    private static let sqlKeywords: Set<String> = [
        "ADD", "ALTER", "AND", "AS", "ASC", "BETWEEN", "BY", "CASE", "CREATE", "DELETE", "DESC", "DISTINCT",
        "DROP", "ELSE", "EXISTS", "FROM", "GROUP", "HAVING", "IN", "INDEX", "INNER", "INSERT", "INTO", "IS",
        "JOIN", "LEFT", "LIKE", "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "OUTER", "PRIMARY", "RIGHT",
        "SELECT", "SET", "TABLE", "THEN", "UNION", "UPDATE", "VALUES", "VIEW", "WHEN", "WHERE"
    ]
}
