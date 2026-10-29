import Foundation
import Markdown

/// Renders GitHub Flavored Markdown to HTML: tables, task lists, strikethrough, autolinks,
/// fenced code with syntax highlighting, footnotes, GitHub-style alerts and heading anchors.
nonisolated enum MarkdownRenderer {
    static func html(from source: String) -> String {
        let (body, footnotes) = Footnotes.extract(from: source)
        let document = Document(parsing: body)
        var visitor = HTMLVisitor()
        var html = visitor.visit(document)
        if !footnotes.isEmpty {
            html = Footnotes.apply(to: html, definitions: footnotes)
        }
        return html
    }

    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        var out = ""
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) { out.unicodeScalars.append(scalar) }
            else if scalar == " " || scalar == "-" || scalar == "_" { out.append("-") }
        }
        return out.replacingOccurrences(of: "-+", with: "-", options: .regularExpression).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Strips active content from raw HTML embedded in notes. The preview's Content-Security-Policy is the
    /// main guard; this keeps exported HTML tidy too.
    static func sanitize(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "(?is)<(script|iframe|object|embed|style)\\b.*?</\\1\\s*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?is)<(script|iframe|object|embed|meta|link|base)\\b[^>]*>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)(href|src)\\s*=\\s*([\"'])\\s*javascript:[^\"']*\\2", with: "$1=\"#\"", options: .regularExpression)
        return s
    }

    static func safeURL(_ url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("javascript:") || trimmed.lowercased().hasPrefix("vbscript:") { return "#" }
        return escape(trimmed)
    }
}

nonisolated struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    private var slugCounts: [String: Int] = [:]

    mutating func defaultVisit(_ markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    private func lineAttr(_ markup: Markup) -> String {
        guard let line = markup.range?.lowerBound.line else { return "" }
        return " data-line=\"\(line)\""
    }

    mutating func visitDocument(_ document: Document) -> String {
        defaultVisit(document)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        var base = MarkdownRenderer.slug(heading.plainText)
        if base.isEmpty { base = "section" }
        let count = slugCounts[base, default: 0]
        slugCounts[base] = count + 1
        let id = count == 0 ? base : "\(base)-\(count)"
        let level = min(6, max(1, heading.level))
        return "<h\(level) id=\"\(id)\"\(lineAttr(heading))>\(defaultVisit(heading))</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p\(lineAttr(paragraph))>\(defaultVisit(paragraph))</p>\n"
    }

    mutating func visitText(_ text: Text) -> String { MarkdownRenderer.escape(text.string) }
    mutating func visitEmphasis(_ emphasis: Emphasis) -> String { "<em>\(defaultVisit(emphasis))</em>" }
    mutating func visitStrong(_ strong: Strong) -> String { "<strong>\(defaultVisit(strong))</strong>" }
    mutating func visitStrikethrough(_ s: Strikethrough) -> String { "<del>\(defaultVisit(s))</del>" }
    mutating func visitInlineCode(_ code: InlineCode) -> String { "<code>\(MarkdownRenderer.escape(code.code))</code>" }
    mutating func visitSymbolLink(_ link: SymbolLink) -> String { "<code>\(MarkdownRenderer.escape(link.destination ?? ""))</code>" }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String { "\n" }
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String { "<br>\n" }
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String { "<hr\(lineAttr(thematicBreak))>\n" }
    mutating func visitInlineHTML(_ html: InlineHTML) -> String { MarkdownRenderer.sanitize(html.rawHTML) }
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String { MarkdownRenderer.sanitize(html.rawHTML) }

    mutating func visitLink(_ link: Link) -> String {
        let href = MarkdownRenderer.safeURL(link.destination ?? "")
        let title = link.title.map { " title=\"\(MarkdownRenderer.escape($0))\"" } ?? ""
        return "<a href=\"\(href)\"\(title)>\(defaultVisit(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = MarkdownRenderer.safeURL(image.source ?? "")
        let alt = MarkdownRenderer.escape(image.plainText)
        let title = image.title.map { " title=\"\(MarkdownRenderer.escape($0))\"" } ?? ""
        return "<img src=\"\(src)\" alt=\"\(alt)\"\(title) loading=\"lazy\">"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = (codeBlock.language ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        var code = codeBlock.code
        if code.hasSuffix("\n") { code.removeLast() }
        let highlighted = CodeHighlighter.highlight(code, language: language)
        let cls = language.isEmpty ? "" : " class=\"language-\(MarkdownRenderer.escape(language))\""
        let label = language.isEmpty ? "" : "<span class=\"code-lang\">\(MarkdownRenderer.escape(language))</span>"
        return "<pre\(lineAttr(codeBlock))>\(label)<code\(cls)>\(highlighted)</code></pre>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let children = Array(blockQuote.children)
        if let first = children.first as? Paragraph {
            let firstHTML = defaultVisit(first)
            let pattern = "^\\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\\]\\s*"
            if let range = firstHTML.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let kind = firstHTML[range].dropFirst(2).prefix { $0 != "]" }.lowercased()
                var rest = String(firstHTML[range.upperBound...])
                if rest.hasPrefix("<br>") { rest.removeFirst(4) }
                rest = rest.trimmingCharacters(in: .whitespacesAndNewlines)
                var inner = rest.isEmpty ? "" : "<p>\(rest)</p>\n"
                inner += children.dropFirst().map { visit($0) }.joined()
                return "<div class=\"alert alert-\(kind)\"\(lineAttr(blockQuote))><p class=\"alert-title\">\(kind.capitalized)</p>\n\(inner)</div>\n"
            }
        }
        return "<blockquote\(lineAttr(blockQuote))>\n\(defaultVisit(blockQuote))</blockquote>\n"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        let isTasks = list.listItems.contains { $0.checkbox != nil }
        return "<ul\(isTasks ? " class=\"tasks\"" : "")\(lineAttr(list))>\n\(defaultVisit(list))</ul>\n"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        let start = list.startIndex == 1 ? "" : " start=\"\(list.startIndex)\""
        return "<ol\(start)\(lineAttr(list))>\n\(defaultVisit(list))</ol>\n"
    }

    mutating func visitListItem(_ item: ListItem) -> String {
        let content = defaultVisit(item)
        guard let checkbox = item.checkbox else { return "<li\(lineAttr(item))>\(content)</li>\n" }
        let line = item.range?.lowerBound.line ?? 0
        let checked = checkbox == .checked ? " checked" : ""
        let box = "<input type=\"checkbox\" data-line=\"\(line)\"\(checked)>"
        return "<li class=\"task\(checkbox == .checked ? " done" : "")\"\(lineAttr(item))>\(box)\(content)</li>\n"
    }

    mutating func visitTable(_ table: Table) -> String {
        let alignments = table.columnAlignments
        func cells(_ row: Markup, tag: String) -> String {
            var out = ""
            for (index, child) in row.children.enumerated() {
                var align = ""
                if index < alignments.count, let a = alignments[index] {
                    switch a {
                    case .left: align = " style=\"text-align:left\""
                    case .center: align = " style=\"text-align:center\""
                    case .right: align = " style=\"text-align:right\""
                    }
                }
                out += "<\(tag)\(align)>\(defaultVisit(child))</\(tag)>"
            }
            return out
        }
        var html = "<div class=\"table-wrap\"\(lineAttr(table))><table>\n<thead><tr>\(cells(table.head, tag: "th"))</tr></thead>\n<tbody>\n"
        for row in table.body.rows {
            html += "<tr>\(cells(row, tag: "td"))</tr>\n"
        }
        return html + "</tbody></table></div>\n"
    }
}

/// Footnotes aren't part of cmark-gfm's Swift API, so they're handled around the parse:
/// definitions are lifted out before parsing and references are linked afterwards.
nonisolated enum Footnotes {
    struct Definition { let id: String; let text: String }

    static func extract(from source: String) -> (String, [Definition]) {
        guard source.contains("[^") else { return (source, []) }
        var kept: [Substring] = []
        var definitions: [Definition] = []
        var inFence = false
        var current: (id: String, lines: [String])?
        func flush() {
            if let c = current { definitions.append(Definition(id: c.id, text: c.lines.joined(separator: " "))) }
            current = nil
        }
        let regex = try! NSRegularExpression(pattern: "^\\[\\^([^\\]\\s]+)\\]:\\s?(.*)$")
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { inFence.toggle() }
            if !inFence {
                let s = String(line)
                if let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                   let idRange = Range(m.range(at: 1), in: s), let textRange = Range(m.range(at: 2), in: s) {
                    flush()
                    current = (String(s[idRange]), [String(s[textRange])])
                    continue
                }
                if current != nil, line.hasPrefix("    ") || line.hasPrefix("\t") {
                    current?.lines.append(trimmed)
                    continue
                }
                flush()
            }
            kept.append(line)
        }
        flush()
        return (kept.joined(separator: "\n"), definitions)
    }

    static func apply(to html: String, definitions: [Definition]) -> String {
        var order: [String] = []
        let known = Set(definitions.map(\.id))
        // Replace references outside <pre> and <code> blocks.
        let parts = html.components(separatedBy: "<pre")
        var rebuilt: [String] = []
        for (i, part) in parts.enumerated() {
            var segment = part
            var prefix = ""
            if i > 0, let end = segment.range(of: "</pre>") {
                prefix = String(segment[..<end.upperBound])
                segment = String(segment[end.upperBound...])
            }
            let regex = try! NSRegularExpression(pattern: "\\[\\^([^\\]\\s]+)\\]")
            let ns = segment as NSString
            var result = ""
            var last = 0
            for m in regex.matches(in: segment, range: NSRange(location: 0, length: ns.length)) {
                let id = ns.substring(with: m.range(at: 1))
                guard known.contains(id) else { continue }
                if !order.contains(id) { order.append(id) }
                let n = order.firstIndex(of: id)! + 1
                result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
                let safe = MarkdownRenderer.slug(id)
                result += "<sup class=\"fn-ref\"><a href=\"#fn-\(safe)\" id=\"fnref-\(safe)\">\(n)</a></sup>"
                last = m.range.location + m.range.length
            }
            result += ns.substring(from: last)
            rebuilt.append((i > 0 ? "<pre" : "") + prefix + result)
        }
        var out = rebuilt.joined()
        let ordered = order.compactMap { id in definitions.first { $0.id == id } }
            + definitions.filter { !order.contains($0.id) }
        out += "<section class=\"footnotes\"><hr><ol>\n"
        for def in ordered {
            var inner = MarkdownRenderer.html(from: def.text).trimmingCharacters(in: .whitespacesAndNewlines)
            if inner.hasPrefix("<p"), let close = inner.firstIndex(of: ">"), inner.hasSuffix("</p>") {
                inner = String(inner[inner.index(after: close)..<inner.index(inner.endIndex, offsetBy: -4)])
            }
            let safe = MarkdownRenderer.slug(def.id)
            out += "<li id=\"fn-\(safe)\">\(inner) <a href=\"#fnref-\(safe)\" class=\"fn-back\">↩</a></li>\n"
        }
        return out + "</ol></section>\n"
    }
}
