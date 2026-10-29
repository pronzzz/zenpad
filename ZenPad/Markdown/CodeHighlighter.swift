import Foundation

/// A small, dependency-free syntax highlighter for fenced code blocks in the preview.
/// It recognises comments, strings, numbers, keywords, types and function calls for common languages.
nonisolated enum CodeHighlighter {
    struct Language {
        var keywords: Set<String>
        var lineComment: [String] = ["//"]
        var blockComment: (String, String)? = ("/*", "*/")
        var stringDelimiters: [String] = ["\"", "'"]
    }

    static func language(named name: String) -> Language? {
        switch name {
        case "swift":
            return Language(keywords: words("let var func if else guard return struct class enum protocol extension import for in while repeat switch case default break continue where self Self init deinit throws throw try catch async await some any nil true false static private fileprivate internal public open final override mutating inout defer do is as weak lazy actor nonisolated"), stringDelimiters: ["\"\"\"", "\""])
        case "js", "javascript", "jsx", "ts", "typescript", "tsx":
            return Language(keywords: words("const let var function return if else for while do switch case default break continue new class extends import export from as async await try catch finally throw typeof instanceof in of null undefined true false this super yield interface type enum implements public private protected readonly static"), stringDelimiters: ["`", "\"", "'"])
        case "python", "py":
            return Language(keywords: words("def class return if elif else for while in not and or is import from as with try except finally raise pass break continue lambda yield None True False self async await global nonlocal assert del print"), lineComment: ["#"], blockComment: nil, stringDelimiters: ["\"\"\"", "'''", "\"", "'"])
        case "rust", "rs":
            return Language(keywords: words("fn let mut pub struct enum impl trait use mod crate self Self super match if else loop while for in return break continue as ref move async await dyn where type const static unsafe true false Some None Ok Err"))
        case "go", "golang":
            return Language(keywords: words("func package import var const type struct interface map chan go defer select return if else for range switch case default break continue fallthrough nil true false"), stringDelimiters: ["`", "\"", "'"])
        case "c", "cpp", "c++", "h", "hpp", "objc", "objective-c", "java", "kotlin", "kt", "cs", "csharp", "dart", "scala":
            return Language(keywords: words("int char float double void long short unsigned signed bool boolean struct class enum union typedef const static extern return if else for while do switch case default break continue new delete public private protected virtual override final abstract interface extends implements import package namespace using template typename this null nullptr true false fun val var when object companion data sealed suspend try catch finally throw throws async await"))
        case "ruby", "rb":
            return Language(keywords: words("def end class module if elsif else unless while until for in do return yield begin rescue ensure raise nil true false self require attr_accessor puts"), lineComment: ["#"], blockComment: nil)
        case "sh", "bash", "zsh", "shell", "console", "fish":
            return Language(keywords: words("if then else elif fi for in do done while until case esac function return export local echo exit source cd sudo set unset"), lineComment: ["#"], blockComment: nil)
        case "sql":
            return Language(keywords: words("select from where insert into values update set delete create table drop alter add index join left right inner outer on group by order having limit as and or not null is in like distinct primary key foreign references default"), lineComment: ["--"], blockComment: ("/*", "*/"), stringDelimiters: ["'", "\""])
        case "json", "jsonc":
            return Language(keywords: words("true false null"), lineComment: [], blockComment: nil, stringDelimiters: ["\""])
        case "yaml", "yml", "toml", "ini":
            return Language(keywords: words("true false null yes no on off"), lineComment: ["#"], blockComment: nil)
        case "css", "scss", "less":
            return Language(keywords: words("important media import from to"), lineComment: [], blockComment: ("/*", "*/"))
        default:
            return nil
        }
    }

    private static func words(_ s: String) -> Set<String> {
        Set(s.split(separator: " ").map(String.init))
    }

    static func highlight(_ code: String, language name: String) -> String {
        if ["html", "xml", "svg", "plist", "vue"].contains(name) { return highlightMarkup(code) }
        if name == "diff" || name == "patch" { return highlightDiff(code) }
        guard let lang = language(named: name) else { return MarkdownRenderer.escape(code) }
        let isSQL = name == "sql"
        let chars = Array(code)
        var out = ""
        var i = 0
        func starts(_ token: String, at index: Int) -> Bool {
            let t = Array(token)
            guard index + t.count <= chars.count else { return false }
            return Array(chars[index..<index + t.count]) == t
        }
        func span(_ cls: String, _ text: String) -> String {
            "<span class=\"tok-\(cls)\">\(MarkdownRenderer.escape(text))</span>"
        }
        outer: while i < chars.count {
            // Comments
            for marker in lang.lineComment where starts(marker, at: i) {
                var j = i
                while j < chars.count && chars[j] != "\n" { j += 1 }
                out += span("c", String(chars[i..<j]))
                i = j
                continue outer
            }
            if let (open, close) = lang.blockComment, starts(open, at: i) {
                var j = i + open.count
                while j < chars.count && !starts(close, at: j) { j += 1 }
                j = min(chars.count, j + close.count)
                out += span("c", String(chars[i..<j]))
                i = j
                continue
            }
            // Strings
            for delim in lang.stringDelimiters where starts(delim, at: i) {
                var j = i + delim.count
                while j < chars.count {
                    if chars[j] == "\\" { j += 2; continue }
                    if starts(delim, at: j) { j += delim.count; break }
                    if delim.count == 1 && delim != "`" && chars[j] == "\n" { break }
                    j += 1
                }
                j = min(j, chars.count)
                let text = String(chars[i..<j])
                // JSON object keys read better in a different colour.
                var k = j
                while k < chars.count && (chars[k] == " " || chars[k] == "\t") { k += 1 }
                let isKey = name.hasPrefix("json") && k < chars.count && chars[k] == ":"
                out += span(isKey ? "p" : "s", text)
                i = j
                continue outer
            }
            let c = chars[i]
            // Numbers
            if c.isNumber, i == 0 || !(chars[i - 1].isLetter || chars[i - 1] == "_") {
                var j = i
                while j < chars.count && (chars[j].isHexDigit || chars[j] == "." || chars[j] == "_" || chars[j] == "x") { j += 1 }
                out += span("n", String(chars[i..<j]))
                i = j
                continue
            }
            // Identifiers
            if c.isLetter || c == "_" || c == "@" || c == "$" {
                var j = i + 1
                while j < chars.count && (chars[j].isLetter || chars[j].isNumber || chars[j] == "_") { j += 1 }
                let word = String(chars[i..<j])
                let lookup = isSQL ? word.lowercased() : word
                if lang.keywords.contains(lookup) {
                    out += span("k", word)
                } else if word.first == "@" {
                    out += span("a", word)
                } else if j < chars.count && chars[j] == "(" {
                    out += span("f", word)
                } else if let first = word.first, first.isUppercase, word.count > 1 {
                    out += span("t", word)
                } else {
                    out += MarkdownRenderer.escape(word)
                }
                i = j
                continue
            }
            out += MarkdownRenderer.escape(String(c))
            i += 1
        }
        return out
    }

    private static func highlightMarkup(_ code: String) -> String {
        let escaped = MarkdownRenderer.escape(code)
        var s = escaped
        s = s.replacingOccurrences(of: "(&lt;!--[\\s\\S]*?--&gt;)", with: "<span class=\"tok-c\">$1</span>", options: .regularExpression)
        s = s.replacingOccurrences(of: "(&lt;/?)([A-Za-z][\\w:-]*)", with: "$1<span class=\"tok-k\">$2</span>", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s([A-Za-z_:][\\w:.-]*)=(&quot;[^&]*?&quot;)", with: " <span class=\"tok-p\">$1</span>=<span class=\"tok-s\">$2</span>", options: .regularExpression)
        return s
    }

    private static func highlightDiff(_ code: String) -> String {
        code.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let text = MarkdownRenderer.escape(String(line))
            if line.hasPrefix("+") { return "<span class=\"tok-add\">\(text)</span>" }
            if line.hasPrefix("-") { return "<span class=\"tok-del\">\(text)</span>" }
            if line.hasPrefix("@@") { return "<span class=\"tok-k\">\(text)</span>" }
            return text
        }.joined(separator: "\n")
    }
}
