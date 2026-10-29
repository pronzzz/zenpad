import AppKit

extension NSAttributedString.Key {
    /// Block decoration drawn behind text by `ZenLayoutManager`: "code" or "quote".
    static let zenBlock = NSAttributedString.Key("ZenBlock")
    /// Inline code span, drawn as a rounded pill.
    static let zenInlineCode = NSAttributedString.Key("ZenInlineCode")
    /// A task checkbox ("[ ]" or "[x]"), clickable in the editor. Value: Bool (checked).
    static let zenTask = NSAttributedString.Key("ZenTask")
    /// Link destination; ⌘-click opens it.
    static let zenLink = NSAttributedString.Key("ZenLink")
}

/// Styles Markdown source in place: the syntax stays visible but quiet, and the text takes on
/// its meaning (bigger headings, bold, italic, code, links, checkboxes, quotes).
final class MarkdownStyler {
    var theme: EditorTheme {
        didSet { fontCache.removeAll() }
    }
    var markdownEnabled = true

    private var fontCache: [String: NSFont] = [:]
    private var lastFenceCount = -1

    init(theme: EditorTheme) {
        self.theme = theme
    }

    // MARK: Regular expressions

    private static func re(_ pattern: String, _ options: NSRegularExpression.Options = [.anchorsMatchLines]) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private static let frontMatter = re("\\A---[ \\t]*\\n[\\s\\S]*?\\n---[ \\t]*$")
    private static let heading = re("^(#{1,6})([ \\t]+)(.*)$")
    private static let quote = re("^((?: {0,3}>[ \\t]?)+)(.*)$")
    private static let list = re("^([ \\t]*)([-*+]|\\d{1,9}[.)])([ \\t]+)(\\[[ xX]\\][ \\t]+)?(.*)$")
    private static let rule = re("^ {0,3}([-*_])(?:[ \\t]*\\1){2,}[ \\t]*$")
    private static let tableRow = re("^[ \\t]*\\|.*\\|[ \\t]*$")
    private static let inlineCode = re("(`+)(?!`)(.+?)(?<!`)\\1(?!`)", [])
    private static let bold = re("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1", [])
    private static let italic = re("(?<![*_\\\\\\w])([*_])(?=[^\\s*_])(.+?)(?<=[^\\s\\\\])\\1(?![*_\\w])", [])
    private static let strike = re("(~~)(?=\\S)(.+?)(?<=\\S)~~", [])
    private static let highlight = re("(==)(?=\\S)(.+?)(?<=\\S)==", [])
    private static let image = re("(!\\[)([^\\]\\n]*)(\\]\\()([^)\\n]*)(\\))", [])
    private static let link = re("(?<!!)(\\[)([^\\]\\n]+)(\\]\\()([^)\\s\\n]+)([^)\\n]*)(\\))", [])
    private static let autolink = re("<?\\b(https?://[^\\s<>()\\[\\]]+[^\\s<>()\\[\\].,;:!?'\"])>?", [])
    private static let footnote = re("\\[\\^[^\\]\\s]+\\]:?", [])
    private static let html = re("</?[A-Za-z][A-Za-z0-9-]*(?:\\s[^<>\\n]*)?/?>|<!--[\\s\\S]*?-->", [])
    private static let escape = re("\\\\[\\\\`*_{}\\[\\]()#+\\-.!|~<>]", [])

    // MARK: Attributes

    func paragraphStyle(headIndent: CGFloat = 0, firstLineIndent: CGFloat? = nil, tailIndent: CGFloat = 0, spacingBefore: CGFloat = 0) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = theme.lineHeightMultiple
        style.paragraphSpacing = theme.font.pointSize * 0.05
        style.paragraphSpacingBefore = spacingBefore
        style.headIndent = headIndent
        style.firstLineHeadIndent = firstLineIndent ?? 0
        style.tailIndent = tailIndent
        style.lineBreakMode = .byWordWrapping
        return style
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: theme.font, .foregroundColor: Palette.ink, .paragraphStyle: paragraphStyle()]
    }

    private func font(_ base: NSFont, bold: Bool = false, italic: Bool = false, size: CGFloat? = nil) -> NSFont {
        let key = "\(base.fontName)|\(size ?? base.pointSize)|\(bold)|\(italic)"
        if let cached = fontCache[key] { return cached }
        var f = base
        if let size { f = f.sized(size) }
        f = f.with(bold: bold, italic: italic)
        fontCache[key] = f
        return f
    }

    private func headingFont(level: Int) -> NSFont {
        let scale: [CGFloat] = [1.55, 1.32, 1.16, 1.06, 1.0, 1.0]
        return font(theme.font, bold: true, size: (theme.font.pointSize * scale[max(0, min(5, level - 1))]).rounded())
    }

    // MARK: Styling

    /// Restyles the text. When `edited` is given and the document is large, only the touched
    /// paragraphs are restyled unless the edit changed code fences.
    func restyle(_ storage: NSTextStorage, edited: NSRange? = nil, inEditing: Bool = false) {
        let ns = storage.string as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard full.length > 0 else { return }

        let fences = markdownEnabled ? Self.fencedBlocks(in: ns) : []
        var target = full
        if let edited, ns.length > 30_000, fences.count == lastFenceCount {
            let para = ns.paragraphRange(for: NSRange(location: min(edited.location, ns.length), length: min(edited.length, ns.length - min(edited.location, ns.length))))
            if !fences.contains(where: { NSIntersectionRange($0, para).length > 0 || NSMaxRange($0) == para.location }) {
                target = para
            }
        }
        lastFenceCount = fences.count

        if !inEditing { storage.beginEditing() }
        defer { if !inEditing { storage.endEditing() } }
        storage.setAttributes(baseAttributes, range: target)
        guard markdownEnabled else { return }

        var protected: [NSRange] = []

        if let fm = Self.frontMatter.firstMatch(in: storage.string, range: full)?.range, NSIntersectionRange(fm, target).length > 0 {
            storage.addAttributes([.font: theme.codeFont, .foregroundColor: Palette.muted], range: fm)
            protected.append(fm)
        }

        for block in fences where NSIntersectionRange(block, target).length > 0 {
            storage.addAttributes([.font: theme.codeFont, .foregroundColor: Palette.ink, .zenBlock: "code",
                                   .paragraphStyle: paragraphStyle(headIndent: 14, firstLineIndent: 14, tailIndent: -14)], range: block)
            let firstLine = ns.lineRange(for: NSRange(location: block.location, length: 0))
            storage.addAttribute(.foregroundColor, value: Palette.markup, range: NSIntersectionRange(firstLine, block))
            let lastLine = ns.lineRange(for: NSRange(location: max(block.location, NSMaxRange(block) - 1), length: 0))
            if lastLine.location != firstLine.location {
                storage.addAttribute(.foregroundColor, value: Palette.markup, range: NSIntersectionRange(lastLine, block))
            }
            protected.append(block)
        }

        func isProtected(_ r: NSRange) -> Bool {
            protected.contains { NSIntersectionRange($0, r).length > 0 }
        }

        func each(_ regex: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            regex.enumerateMatches(in: storage.string, range: target) { match, _, _ in
                guard let match, !isProtected(match.range) else { return }
                body(match)
            }
        }

        func markup(_ r: NSRange) {
            guard r.location != NSNotFound, r.length > 0 else { return }
            storage.addAttribute(.foregroundColor, value: Palette.markup, range: r)
        }

        func addTraits(_ r: NSRange, bold: Bool = false, italic: Bool = false) {
            storage.enumerateAttribute(.font, in: r) { value, sub, _ in
                let base = (value as? NSFont) ?? theme.font
                let styled = font(base, bold: bold, italic: italic)
                storage.addAttribute(.font, value: styled, range: sub)
                if italic && !styled.fontDescriptor.symbolicTraits.contains(.italic) {
                    storage.addAttribute(.obliqueness, value: 0.16, range: sub)
                }
            }
        }

        // Block-level syntax
        each(Self.heading) { m in
            let level = m.range(at: 1).length
            let hf = headingFont(level: level)
            storage.addAttributes([.font: hf, .paragraphStyle: paragraphStyle(spacingBefore: hf.pointSize * 0.35)], range: m.range)
            markup(m.range(at: 1))
        }
        each(Self.quote) { m in
            // Include the newline so consecutive quote lines share one continuous bar.
            let line = NSIntersectionRange(ns.lineRange(for: m.range), target)
            storage.addAttributes([.foregroundColor: Palette.muted, .zenBlock: "quote",
                                   .paragraphStyle: paragraphStyle(headIndent: 16, firstLineIndent: 16)], range: line)
            markup(m.range(at: 1))
        }
        each(Self.list) { m in
            let indent = ns.substring(with: m.range(at: 1))
            let marker = ns.substring(with: m.range(at: 2)) + ns.substring(with: m.range(at: 3))
            var prefix = indent.replacingOccurrences(of: "\t", with: "    ") + marker
            storage.addAttribute(.foregroundColor, value: Palette.accent.withAlphaComponent(0.75), range: m.range(at: 2))
            let box = m.range(at: 4)
            if box.location != NSNotFound {
                prefix += ns.substring(with: box)
                let checked = ns.substring(with: box).lowercased().contains("x")
                let boxCore = NSRange(location: box.location, length: 3)
                storage.addAttributes([.zenTask: checked, .foregroundColor: Palette.accent], range: boxCore)
                if checked {
                    let content = m.range(at: 5)
                    if content.length > 0 {
                        storage.addAttributes([.foregroundColor: Palette.muted, .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                               .strikethroughColor: Palette.markup], range: content)
                    }
                }
            }
            let width = (prefix as NSString).size(withAttributes: [.font: theme.font]).width
            storage.addAttribute(.paragraphStyle, value: paragraphStyle(headIndent: width), range: m.range)
        }
        each(Self.rule) { m in markup(m.range) }
        each(Self.tableRow) { m in
            storage.addAttribute(.font, value: theme.codeFont, range: m.range)
            let line = ns.substring(with: m.range) as NSString
            var search = NSRange(location: 0, length: line.length)
            while true {
                let found = line.range(of: "|", options: [], range: search)
                if found.location == NSNotFound { break }
                markup(NSRange(location: m.range.location + found.location, length: 1))
                search = NSRange(location: NSMaxRange(found), length: line.length - NSMaxRange(found))
            }
            if line.trimmingCharacters(in: CharacterSet(charactersIn: "|-: \t")).isEmpty { markup(m.range) }
        }

        // Inline syntax. Inline code is matched first and protected from everything else.
        each(Self.inlineCode) { m in
            storage.addAttributes([.font: theme.codeFont, .zenInlineCode: true], range: m.range)
            markup(m.range(at: 1))
            markup(NSRange(location: NSMaxRange(m.range) - m.range(at: 1).length, length: m.range(at: 1).length))
            protected.append(m.range)
        }
        each(Self.bold) { m in
            addTraits(m.range, bold: true)
            markup(NSRange(location: m.range.location, length: 2))
            markup(NSRange(location: NSMaxRange(m.range) - 2, length: 2))
        }
        each(Self.italic) { m in
            addTraits(m.range, italic: true)
            markup(NSRange(location: m.range.location, length: 1))
            markup(NSRange(location: NSMaxRange(m.range) - 1, length: 1))
        }
        each(Self.strike) { m in
            storage.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: Palette.muted], range: m.range(at: 2))
            markup(NSRange(location: m.range.location, length: 2))
            markup(NSRange(location: NSMaxRange(m.range) - 2, length: 2))
        }
        each(Self.highlight) { m in
            storage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.28), range: m.range(at: 2))
            markup(NSRange(location: m.range.location, length: 2))
            markup(NSRange(location: NSMaxRange(m.range) - 2, length: 2))
        }
        var linkRanges: [NSRange] = []
        each(Self.image) { m in
            storage.addAttribute(.foregroundColor, value: Palette.muted, range: m.range)
            markup(m.range(at: 1)); markup(m.range(at: 3)); markup(m.range(at: 4)); markup(m.range(at: 5))
            linkRanges.append(m.range)
        }
        each(Self.link) { m in
            guard !linkRanges.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) else { return }
            let url = ns.substring(with: m.range(at: 4))
            storage.addAttributes([.foregroundColor: Palette.accent, .zenLink: url], range: m.range(at: 2))
            markup(m.range(at: 1)); markup(m.range(at: 3)); markup(m.range(at: 4)); markup(m.range(at: 5)); markup(m.range(at: 6))
            linkRanges.append(m.range)
        }
        each(Self.autolink) { m in
            guard !linkRanges.contains(where: { NSIntersectionRange($0, m.range).length > 0 }) else { return }
            storage.addAttributes([.foregroundColor: Palette.accent, .zenLink: ns.substring(with: m.range(at: 1))], range: m.range)
        }
        each(Self.footnote) { m in storage.addAttribute(.foregroundColor, value: Palette.accent, range: m.range) }
        each(Self.html) { m in markup(m.range) }
        each(Self.escape) { m in markup(NSRange(location: m.range.location, length: 1)) }
    }

    /// Fenced code blocks (``` or ~~~), found with a line scan. An unclosed fence runs to the end.
    static func fencedBlocks(in ns: NSString) -> [NSRange] {
        var blocks: [NSRange] = []
        var location = 0
        var open: (start: Int, marker: unichar, count: Int)?
        while location < ns.length {
            let line = ns.lineRange(for: NSRange(location: location, length: 0))
            var i = line.location
            var spaces = 0
            while i < NSMaxRange(line), ns.character(at: i) == 32, spaces < 3 { i += 1; spaces += 1 }
            var run = 0
            let first: unichar = i < NSMaxRange(line) ? ns.character(at: i) : 0
            if first == 96 || first == 126 {
                while i + run < NSMaxRange(line), ns.character(at: i + run) == first { run += 1 }
            }
            if let o = open {
                if first == o.marker, run >= o.count {
                    let rest = ns.substring(with: NSRange(location: i + run, length: NSMaxRange(line) - i - run))
                    if rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        var end = NSMaxRange(line)
                        if end > line.location, ns.character(at: end - 1) == 10 { end -= 1 }
                        blocks.append(NSRange(location: o.start, length: end - o.start))
                        open = nil
                    }
                }
            } else if run >= 3 {
                open = (line.location, first, run)
            }
            location = NSMaxRange(line)
        }
        if let o = open { blocks.append(NSRange(location: o.start, length: ns.length - o.start)) }
        return blocks
    }
}
