import Foundation
import AppKit

// MARK: - Syntax Highlighting Service

class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    
    // MARK: - Language Detection
    
    enum Language: String, CaseIterable {
        case plainText = "Plain Text"
        case markdown = "Markdown"
        case json = "JSON"
        case javascript = "JavaScript"
        case python = "Python"
        case html = "HTML"
        case css = "CSS"
        case swift = "Swift"
        case yaml = "YAML"
        case shell = "Shell"
        
        var fileExtensions: [String] {
            switch self {
            case .plainText: return ["txt"]
            case .markdown: return ["md", "markdown"]
            case .json: return ["json"]
            case .javascript: return ["js", "jsx", "ts", "tsx"]
            case .python: return ["py", "pyw"]
            case .html: return ["html", "htm"]
            case .css: return ["css", "scss", "sass"]
            case .swift: return ["swift"]
            case .yaml: return ["yaml", "yml"]
            case .shell: return ["sh", "bash", "zsh"]
            }
        }
        
        static func detect(from fileExtension: String) -> Language {
            let ext = fileExtension.lowercased()
            return allCases.first { $0.fileExtensions.contains(ext) } ?? .plainText
        }
        
        static func detect(from url: URL) -> Language {
            detect(from: url.pathExtension)
        }
    }
    
    // MARK: - Token Types
    
    enum TokenType {
        case keyword
        case string
        case number
        case comment
        case function
        case variable
        case type
        case property
        case tag
        case attribute
        case punctuation
        case `operator`
        case heading
        case link
        case emphasis
        case codeBlock
    }
    
    // MARK: - Theme
    
    struct Theme {
        let keyword: NSColor
        let string: NSColor
        let number: NSColor
        let comment: NSColor
        let function: NSColor
        let variable: NSColor
        let type: NSColor
        let property: NSColor
        let tag: NSColor
        let attribute: NSColor
        let punctuation: NSColor
        let `operator`: NSColor
        let heading: NSColor
        let link: NSColor
        let emphasis: NSColor
        let codeBlock: NSColor
        let background: NSColor
        let foreground: NSColor
        
        static var light: Theme {
            Theme(
                keyword: NSColor(red: 0.61, green: 0.12, blue: 0.70, alpha: 1),     // Purple
                string: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),      // Red
                number: NSColor(red: 0.11, green: 0.43, blue: 0.69, alpha: 1),      // Blue
                comment: NSColor(red: 0.42, green: 0.47, blue: 0.51, alpha: 1),     // Gray
                function: NSColor(red: 0.15, green: 0.53, blue: 0.56, alpha: 1),    // Teal
                variable: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),    // Dark gray
                type: NSColor(red: 0.11, green: 0.43, blue: 0.69, alpha: 1),        // Blue
                property: NSColor(red: 0.15, green: 0.53, blue: 0.56, alpha: 1),    // Teal
                tag: NSColor(red: 0.13, green: 0.52, blue: 0.25, alpha: 1),         // Green
                attribute: NSColor(red: 0.61, green: 0.12, blue: 0.70, alpha: 1),   // Purple
                punctuation: NSColor(red: 0.30, green: 0.30, blue: 0.30, alpha: 1), // Gray
                operator: NSColor(red: 0.61, green: 0.12, blue: 0.70, alpha: 1),    // Purple
                heading: NSColor(red: 0.11, green: 0.43, blue: 0.69, alpha: 1),     // Blue
                link: NSColor(red: 0.11, green: 0.43, blue: 0.69, alpha: 1),        // Blue
                emphasis: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1),    // Dark
                codeBlock: NSColor(red: 0.77, green: 0.10, blue: 0.09, alpha: 1),   // Red
                background: .white,
                foreground: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1)
            )
        }
        
        static var dark: Theme {
            Theme(
                keyword: NSColor(red: 0.78, green: 0.56, blue: 0.93, alpha: 1),     // Light purple
                string: NSColor(red: 0.90, green: 0.63, blue: 0.47, alpha: 1),      // Orange
                number: NSColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1),      // Light green
                comment: NSColor(red: 0.50, green: 0.55, blue: 0.60, alpha: 1),     // Gray
                function: NSColor(red: 0.51, green: 0.78, blue: 0.88, alpha: 1),    // Light blue
                variable: NSColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1),    // Light gray
                type: NSColor(red: 0.51, green: 0.78, blue: 0.88, alpha: 1),        // Light blue
                property: NSColor(red: 0.51, green: 0.78, blue: 0.88, alpha: 1),    // Light blue
                tag: NSColor(red: 0.94, green: 0.68, blue: 0.62, alpha: 1),         // Salmon
                attribute: NSColor(red: 0.78, green: 0.56, blue: 0.93, alpha: 1),   // Light purple
                punctuation: NSColor(red: 0.70, green: 0.70, blue: 0.70, alpha: 1), // Gray
                operator: NSColor(red: 0.90, green: 0.63, blue: 0.47, alpha: 1),    // Orange
                heading: NSColor(red: 0.51, green: 0.78, blue: 0.88, alpha: 1),     // Light blue
                link: NSColor(red: 0.51, green: 0.78, blue: 0.88, alpha: 1),        // Light blue
                emphasis: NSColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1),    // Light
                codeBlock: NSColor(red: 0.71, green: 0.84, blue: 0.66, alpha: 1),   // Light green
                background: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
                foreground: NSColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1)
            )
        }
        
        func color(for tokenType: TokenType) -> NSColor {
            switch tokenType {
            case .keyword: return keyword
            case .string: return string
            case .number: return number
            case .comment: return comment
            case .function: return function
            case .variable: return variable
            case .type: return type
            case .property: return property
            case .tag: return tag
            case .attribute: return attribute
            case .punctuation: return punctuation
            case .operator: return `operator`
            case .heading: return heading
            case .link: return link
            case .emphasis: return emphasis
            case .codeBlock: return codeBlock
            }
        }
    }
    
    // MARK: - Highlighting Patterns
    
    struct LanguagePattern {
        let pattern: String
        let tokenType: TokenType
        let options: NSRegularExpression.Options
        
        init(_ pattern: String, _ tokenType: TokenType, options: NSRegularExpression.Options = []) {
            self.pattern = pattern
            self.tokenType = tokenType
            self.options = options
        }
    }
    
    private func patterns(for language: Language) -> [LanguagePattern] {
        switch language {
        case .json:
            return [
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"\\s*:", .property),
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", .string),
                LanguagePattern("-?\\d+\\.?\\d*(?:[eE][+-]?\\d+)?", .number),
                LanguagePattern("\\b(true|false|null)\\b", .keyword),
                LanguagePattern("[{}\\[\\]:,]", .punctuation)
            ]
            
        case .javascript:
            return [
                LanguagePattern("//.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("/\\*[\\s\\S]*?\\*/", .comment),
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", .string),
                LanguagePattern("'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", .string),
                LanguagePattern("`[^`]*`", .string),
                LanguagePattern("\\b(const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|async|await|try|catch|finally|throw|typeof|instanceof)\\b", .keyword),
                LanguagePattern("\\b(true|false|null|undefined|NaN|Infinity)\\b", .keyword),
                LanguagePattern("\\b\\d+\\.?\\d*\\b", .number),
                LanguagePattern("\\b([A-Z][a-zA-Z0-9]*)\\b", .type),
                LanguagePattern("\\b([a-z_][a-zA-Z0-9_]*)\\s*\\(", .function),
                LanguagePattern("[{}\\[\\]();,.]", .punctuation),
                LanguagePattern("[+\\-*/%=<>!&|^~?:]", .operator)
            ]
            
        case .python:
            return [
                LanguagePattern("#.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("\"\"\"[\\s\\S]*?\"\"\"", .string),
                LanguagePattern("'''[\\s\\S]*?'''", .string),
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", .string),
                LanguagePattern("'[^'\\\\]*(?:\\\\.[^'\\\\]*)*'", .string),
                LanguagePattern("\\b(def|class|import|from|as|return|if|elif|else|for|while|break|continue|pass|raise|try|except|finally|with|lambda|yield|global|nonlocal|assert|del|in|is|and|or|not)\\b", .keyword),
                LanguagePattern("\\b(True|False|None)\\b", .keyword),
                LanguagePattern("\\b\\d+\\.?\\d*\\b", .number),
                LanguagePattern("\\b([A-Z][a-zA-Z0-9_]*)\\b", .type),
                LanguagePattern("\\bdef\\s+([a-z_][a-zA-Z0-9_]*)", .function),
                LanguagePattern("[{}\\[\\]():,.]", .punctuation),
                LanguagePattern("[+\\-*/%=<>!@&|^~]", .operator)
            ]
            
        case .html:
            return [
                LanguagePattern("<!--[\\s\\S]*?-->", .comment),
                LanguagePattern("</?([a-zA-Z][a-zA-Z0-9]*)", .tag),
                LanguagePattern("\\b([a-zA-Z-]+)=", .attribute),
                LanguagePattern("\"[^\"]*\"", .string),
                LanguagePattern("'[^']*'", .string),
                LanguagePattern("[<>=/]", .punctuation)
            ]
            
        case .css:
            return [
                LanguagePattern("/\\*[\\s\\S]*?\\*/", .comment),
                LanguagePattern("([.#][a-zA-Z][a-zA-Z0-9_-]*)", .type),
                LanguagePattern("@[a-zA-Z]+", .keyword),
                LanguagePattern("([a-zA-Z-]+)\\s*:", .property),
                LanguagePattern("\"[^\"]*\"", .string),
                LanguagePattern("'[^']*'", .string),
                LanguagePattern("#[0-9a-fA-F]{3,8}", .number),
                LanguagePattern("\\b\\d+(\\.\\d+)?(px|em|rem|%|vh|vw|pt|cm|mm)?\\b", .number),
                LanguagePattern("[{}();:,]", .punctuation)
            ]
            
        case .markdown:
            return [
                LanguagePattern("^#{1,6}\\s.*$", .heading, options: .anchorsMatchLines),
                LanguagePattern("\\*\\*[^*]+\\*\\*", .emphasis),
                LanguagePattern("__[^_]+__", .emphasis),
                LanguagePattern("\\*[^*]+\\*", .emphasis),
                LanguagePattern("_[^_]+_", .emphasis),
                LanguagePattern("`[^`]+`", .codeBlock),
                LanguagePattern("```[\\s\\S]*?```", .codeBlock),
                LanguagePattern("\\[([^\\]]+)\\]\\(([^)]+)\\)", .link),
                LanguagePattern("^>\\s.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("^[-*+]\\s", .punctuation, options: .anchorsMatchLines),
                LanguagePattern("^\\d+\\.\\s", .punctuation, options: .anchorsMatchLines)
            ]
            
        case .swift:
            return [
                LanguagePattern("//.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("/\\*[\\s\\S]*?\\*/", .comment),
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", .string),
                LanguagePattern("\\b(import|class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|while|repeat|break|continue|return|throw|throws|try|catch|as|is|in|where|self|Self|super|init|deinit|get|set|willSet|didSet|lazy|static|final|override|mutating|nonmutating|convenience|required|open|public|internal|fileprivate|private|weak|unowned|inout|some|any|async|await|actor)\\b", .keyword),
                LanguagePattern("\\b(true|false|nil)\\b", .keyword),
                LanguagePattern("\\b\\d+\\.?\\d*\\b", .number),
                LanguagePattern("\\b([A-Z][a-zA-Z0-9]*)\\b", .type),
                LanguagePattern("\\bfunc\\s+([a-z_][a-zA-Z0-9_]*)", .function),
                LanguagePattern("[{}\\[\\]():,.<>]", .punctuation),
                LanguagePattern("[+\\-*/%=<>!&|^~?:]", .operator),
                LanguagePattern("@[a-zA-Z]+", .attribute)
            ]
            
        case .yaml:
            return [
                LanguagePattern("#.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("^[a-zA-Z_][a-zA-Z0-9_]*:", .property, options: .anchorsMatchLines),
                LanguagePattern("\"[^\"]*\"", .string),
                LanguagePattern("'[^']*'", .string),
                LanguagePattern("\\b(true|false|null|yes|no|on|off)\\b", .keyword),
                LanguagePattern("\\b\\d+\\.?\\d*\\b", .number),
                LanguagePattern("[:\\-|>]", .punctuation)
            ]
            
        case .shell:
            return [
                LanguagePattern("#.*$", .comment, options: .anchorsMatchLines),
                LanguagePattern("\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\"", .string),
                LanguagePattern("'[^']*'", .string),
                LanguagePattern("\\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit|break|continue|export|source|alias|unalias|cd|pwd|echo|printf|read|local|declare)\\b", .keyword),
                LanguageParameter("\\$[a-zA-Z_][a-zA-Z0-9_]*", .variable),
                LanguagePattern("\\$\\{[^}]+\\}", .variable),
                LanguagePattern("\\b\\d+\\b", .number),
                LanguagePattern("[|&;()<>]", .punctuation)
            ]
            
        case .plainText:
            return []
        }
    }
    
    // MARK: - Apply Highlighting
    
    func highlight(_ text: String, language: Language, theme: Theme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)
        
        // Apply base style
        attributedString.addAttributes([
            .foregroundColor: theme.foreground,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        ], range: fullRange)
        
        // Apply syntax highlighting
        let languagePatterns = patterns(for: language)
        
        for languagePattern in languagePatterns {
            do {
                let regex = try NSRegularExpression(pattern: languagePattern.pattern, options: languagePattern.options)
                let matches = regex.matches(in: text, options: [], range: fullRange)
                
                for match in matches {
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: theme.color(for: languagePattern.tokenType),
                        range: match.range
                    )
                }
            } catch {
                print("Regex error for pattern \(languagePattern.pattern): \(error)")
            }
        }
        
        return attributedString
    }
}

// Typo fix - should be LanguagePattern, not LanguageParameter
private func LanguageParameter(_ pattern: String, _ tokenType: SyntaxHighlighter.TokenType, options: NSRegularExpression.Options = []) -> SyntaxHighlighter.LanguagePattern {
    return SyntaxHighlighter.LanguagePattern(pattern, tokenType, options: options)
}
