import Foundation

/// Pure text transformations behind the editor's Markdown commands. Each returns the range to
/// replace, the replacement, and where the selection should land.
nonisolated enum MarkdownEditing {
    struct Edit: Equatable {
        var range: NSRange
        var replacement: String
        var selection: NSRange
    }

    // MARK: Lists

    struct ListPrefix: Equatable {
        var prefix: String       // full prefix including indent, marker, space and checkbox
        var continuation: String // prefix for the next item
        var isEmptyItem: Bool    // the line has a marker but no content
    }

    private static let listRegex = try! NSRegularExpression(pattern: "^([ \\t]*)(?:([-*+])|(\\d{1,9})([.)]))([ \\t]+)(\\[[ xX]\\][ \\t]+)?")
    private static let quoteRegex = try! NSRegularExpression(pattern: "^((?: {0,3}>[ \\t]?)+)")

    static func listPrefix(of line: String) -> ListPrefix? {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let m = listRegex.firstMatch(in: line, range: range) {
            let indent = ns.substring(with: m.range(at: 1))
            let space = ns.substring(with: m.range(at: 5))
            var next: String
            if m.range(at: 2).location != NSNotFound {
                next = indent + ns.substring(with: m.range(at: 2)) + space
            } else {
                let number = Int(ns.substring(with: m.range(at: 3))) ?? 0
                next = indent + "\(number + 1)" + ns.substring(with: m.range(at: 4)) + space
            }
            if m.range(at: 6).location != NSNotFound { next += "[ ] " }
            let prefix = ns.substring(to: NSMaxRange(m.range))
            let rest = ns.substring(from: NSMaxRange(m.range)).trimmingCharacters(in: .whitespaces)
            return ListPrefix(prefix: prefix, continuation: next, isEmptyItem: rest.isEmpty)
        }
        if let m = quoteRegex.firstMatch(in: line, range: range) {
            let prefix = ns.substring(with: m.range(at: 1))
            let rest = ns.substring(from: NSMaxRange(m.range)).trimmingCharacters(in: .whitespaces)
            return ListPrefix(prefix: prefix, continuation: prefix.hasSuffix(" ") ? prefix : prefix + " ", isEmptyItem: rest.isEmpty)
        }
        return nil
    }

    /// Return-key behaviour: continue lists, task lists, numbered lists and quotes; an empty item ends the list.
    static func newline(in text: NSString, selection: NSRange) -> Edit? {
        guard selection.location != NSNotFound else { return nil }
        let lineRange = text.lineRange(for: NSRange(location: selection.location, length: 0))
        var lineEnd = NSMaxRange(lineRange)
        if lineEnd > lineRange.location, text.character(at: lineEnd - 1) == 10 { lineEnd -= 1 }
        let line = text.substring(with: NSRange(location: lineRange.location, length: lineEnd - lineRange.location))
        guard let list = listPrefix(of: line) else { return nil }
        // Only continue when the caret is after the marker.
        guard selection.location >= lineRange.location + (list.prefix as NSString).length else { return nil }
        if list.isEmptyItem {
            let r = NSRange(location: lineRange.location, length: lineEnd - lineRange.location)
            return Edit(range: r, replacement: "", selection: NSRange(location: lineRange.location, length: 0))
        }
        let insert = "\n" + list.continuation
        return Edit(range: selection, replacement: insert, selection: NSRange(location: selection.location + (insert as NSString).length, length: 0))
    }

    /// Tab / Shift-Tab on list items indents or outdents every selected line.
    static func indent(in text: NSString, selection: NSRange, outdent: Bool) -> Edit? {
        let lines = text.lineRange(for: selection)
        let block = text.substring(with: lines)
        let parts = block.components(separatedBy: "\n")
        guard parts.contains(where: { listPrefix(of: $0) != nil && !$0.hasPrefix(">") }) else { return nil }
        var removedFirst = 0
        var delta = 0
        let changed = parts.enumerated().map { index, line -> String in
            guard !line.isEmpty || index < parts.count - 1 else { return line }
            if outdent {
                var drop = 0
                if line.hasPrefix("\t") { drop = 1 } else { drop = min(4, line.prefix { $0 == " " }.count) }
                if index == 0 { removedFirst = drop }
                delta -= drop
                return String(line.dropFirst(drop))
            }
            if line.isEmpty { return line }
            delta += 4
            return "    " + line
        }.joined(separator: "\n")
        let firstShift = outdent ? -min(removedFirst, selection.location - lines.location) : 4
        let newSelection = NSRange(location: max(lines.location, selection.location + firstShift),
                                   length: max(0, selection.length + delta - firstShift))
        return Edit(range: lines, replacement: changed, selection: newSelection)
    }

    // MARK: Inline wrapping

    /// Toggles a symmetric marker such as `**`, `_`, `~~` or a backtick around the selection.
    /// With no selection, it wraps the word under the caret or inserts an empty pair.
    static func toggleWrap(in text: NSString, selection: NSRange, marker: String) -> Edit {
        let m = (marker as NSString).length
        var sel = selection
        if sel.length == 0, let word = wordRange(in: text, at: sel.location) { sel = word }

        // Already wrapped just outside the selection?
        if sel.location >= m, NSMaxRange(sel) + m <= text.length,
           text.substring(with: NSRange(location: sel.location - m, length: m)) == marker,
           text.substring(with: NSRange(location: NSMaxRange(sel), length: m)) == marker {
            let inner = text.substring(with: sel)
            return Edit(range: NSRange(location: sel.location - m, length: sel.length + 2 * m), replacement: inner,
                        selection: NSRange(location: sel.location - m, length: sel.length))
        }
        let selected = text.substring(with: sel)
        // Selection includes the markers?
        if selected.count >= 2 * marker.count, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            return Edit(range: sel, replacement: inner, selection: NSRange(location: sel.location, length: (inner as NSString).length))
        }
        if sel.length == 0 {
            return Edit(range: sel, replacement: marker + marker, selection: NSRange(location: sel.location + m, length: 0))
        }
        return Edit(range: sel, replacement: marker + selected + marker, selection: NSRange(location: sel.location + m, length: sel.length))
    }

    static func link(in text: NSString, selection: NSRange) -> Edit {
        let selected = text.substring(with: selection)
        if selected.hasPrefix("http://") || selected.hasPrefix("https://") {
            let replacement = "[](\(selected))"
            return Edit(range: selection, replacement: replacement, selection: NSRange(location: selection.location + 1, length: 0))
        }
        let replacement = "[\(selected)](https://)"
        let urlStart = selection.location + (selected as NSString).length + 3
        return Edit(range: selection, replacement: replacement, selection: NSRange(location: urlStart, length: 8))
    }

    static func wordRange(in text: NSString, at location: Int) -> NSRange? {
        guard text.length > 0 else { return nil }
        let isWord: (unichar) -> Bool = { c in
            guard let scalar = UnicodeScalar(c) else { return false }
            return CharacterSet.alphanumerics.contains(scalar) || c == 39
        }
        var start = location
        var end = location
        while start > 0, isWord(text.character(at: start - 1)) { start -= 1 }
        while end < text.length, isWord(text.character(at: end)) { end += 1 }
        return end > start ? NSRange(location: start, length: end - start) : nil
    }

    // MARK: Line prefixes

    enum LineStyle { case heading(Int), body, quote, bullet, numbered, task }

    private static let anyPrefix = try! NSRegularExpression(pattern: "^(?:#{1,6}[ \\t]+|(?: {0,3}>[ \\t]?)+|[ \\t]*(?:[-*+]|\\d{1,9}[.)])[ \\t]+(?:\\[[ xX]\\][ \\t]+)?)")

    /// Applies (or, if every line already has it, removes) a block style on all selected lines.
    static func setLineStyle(in text: NSString, selection: NSRange, style: LineStyle) -> Edit {
        let lines = text.lineRange(for: selection)
        var block = text.substring(with: lines)
        let trailingNewline = block.hasSuffix("\n")
        if trailingNewline { block.removeLast() }
        let parts = block.components(separatedBy: "\n")

        func strip(_ line: String) -> String {
            let ns = line as NSString
            guard let m = anyPrefix.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return line }
            return ns.substring(from: NSMaxRange(m.range))
        }
        func prefix(for index: Int) -> String {
            switch style {
            case .heading(let level): return String(repeating: "#", count: level) + " "
            case .body: return ""
            case .quote: return "> "
            case .bullet: return "- "
            case .numbered: return "\(index + 1). "
            case .task: return "- [ ] "
            }
        }
        let alreadyStyled = parts.enumerated().allSatisfy { index, line in
            let p = prefix(for: index)
            if case .numbered = style { return line.range(of: "^\\d{1,9}[.)] ", options: .regularExpression) != nil }
            return !p.isEmpty && line.hasPrefix(p) && !(p == "- " && line.hasPrefix("- ["))
        }
        let newParts = parts.enumerated().map { index, line -> String in
            if line.trimmingCharacters(in: .whitespaces).isEmpty && parts.count > 1 { return line }
            let content = strip(line)
            return alreadyStyled ? content : prefix(for: index) + content
        }
        var replacement = newParts.joined(separator: "\n")
        if trailingNewline { replacement += "\n" }
        let length = (replacement as NSString).length - (trailingNewline ? 1 : 0)
        let newSelection = selection.length == 0 && parts.count == 1
            ? NSRange(location: lines.location + length, length: 0)
            : NSRange(location: lines.location, length: length)
        return Edit(range: lines, replacement: replacement, selection: newSelection)
    }

    /// Flips "[ ]" ↔ "[x]" on the task at the given 1-based line number.
    static func toggleTask(in text: String, line: Int) -> String? {
        var lines = text.components(separatedBy: "\n")
        guard line >= 1, line <= lines.count else { return nil }
        let current = lines[line - 1]
        if let r = current.range(of: "\\[ \\]", options: .regularExpression) {
            lines[line - 1] = current.replacingCharacters(in: r, with: "[x]")
        } else if let r = current.range(of: "\\[[xX]\\]", options: .regularExpression) {
            lines[line - 1] = current.replacingCharacters(in: r, with: "[ ]")
        } else {
            return nil
        }
        return lines.joined(separator: "\n")
    }

    /// Headings for the outline menu: (level, title, 1-based line).
    static func headings(in text: String) -> [(level: Int, title: String, line: Int)] {
        var result: [(Int, String, Int)] = []
        var inFence = false
        for (index, raw) in text.components(separatedBy: "\n").enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") { inFence.toggle(); continue }
            guard !inFence, line.hasPrefix("#") else { continue }
            let level = line.prefix { $0 == "#" }.count
            guard level <= 6, line.dropFirst(level).first == " " else { continue }
            let title = Library.stripInlineMarkdown(String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces))
            if !title.isEmpty { result.append((level, title, index + 1)) }
        }
        return result
    }
}
