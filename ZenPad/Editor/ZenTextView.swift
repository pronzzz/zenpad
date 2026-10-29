import AppKit

/// Draws code-block backgrounds, quote bars and inline-code pills behind the text.
final class ZenLayoutManager: NSLayoutManager {
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        MainActor.assumeIsolated { drawDecorations(glyphsToShow, origin) }
    }

    private func drawDecorations(_ glyphsToShow: NSRange, _ origin: NSPoint) {
        guard let storage = textStorage, let container = textContainers.first, storage.length > 0 else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let all = NSRange(location: 0, length: storage.length)
        var drawn = Set<Int>()

        storage.enumerateAttribute(.zenBlock, in: chars) { value, range, _ in
            guard let kind = value as? String else { return }
            var effective = NSRange()
            _ = storage.attribute(.zenBlock, at: range.location, longestEffectiveRange: &effective, in: all)
            guard !drawn.contains(effective.location) else { return }
            drawn.insert(effective.location)
            let glyphs = glyphRange(forCharacterRange: effective, actualCharacterRange: nil)
            var union = NSRect.null
            enumerateLineFragments(forGlyphRange: glyphs) { rect, _, _, _, _ in union = union.union(rect) }
            guard !union.isNull else { return }
            union = union.offsetBy(dx: origin.x, dy: origin.y)
            // Drawing is clipped to the text container, so decorations stay inside it;
            // the styler indents quote and code text to make room.
            if kind == "code" {
                let box = NSRect(x: union.minX, y: union.minY - 3, width: union.width, height: union.height + 6)
                Palette.codeFill.setFill()
                NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
            } else if kind == "quote" {
                let bar = NSRect(x: union.minX + container.lineFragmentPadding + 1, y: union.minY + 7, width: 3, height: union.height - 9)
                Palette.markup.setFill()
                NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
            }
        }

        storage.enumerateAttribute(.zenInlineCode, in: chars) { value, range, _ in
            guard value != nil else { return }
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            Palette.codeFill.setFill()
            enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: container) { rect, _ in
                let pill = rect.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -2, dy: 1)
                NSBezierPath(roundedRect: pill, xRadius: 4, yRadius: 4).fill()
            }
        }
    }
}

/// The writing surface: a plain-text NSTextView that styles Markdown as you type.
final class ZenTextView: NSTextView {
    let styler: MarkdownStyler
    var onTextChange: ((String) -> Void)?
    var onScroll: ((CGFloat) -> Void)?
    var placeholder = "Start writing…"

    var theme: EditorTheme {
        didSet { if theme != oldValue { applyTheme() } }
    }
    var isMarkdown = true {
        didSet { if isMarkdown != oldValue { styler.markdownEnabled = isMarkdown && styleMarkdown; restyleAll() } }
    }
    /// When off, Markdown files are shown as plain text (list continuation still works).
    var styleMarkdown = true {
        didSet { if styleMarkdown != oldValue { styler.markdownEnabled = isMarkdown && styleMarkdown; restyleAll() } }
    }
    var typewriter = false {
        didSet { if typewriter != oldValue { updateInsets(); centerCaret(animated: true) } }
    }
    var focusDimming = false {
        didSet { if focusDimming != oldValue { updateFocusDimming() } }
    }

    private var isProgrammaticChange = false

    /// Builds the TextKit 1 stack (needed for custom background drawing) inside a scroll view.
    static func makeScrollable(theme: EditorTheme) -> (NSScrollView, ZenTextView) {
        let storage = NSTextStorage()
        let layout = ZenLayoutManager()
        layout.allowsNonContiguousLayout = true
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 5
        layout.addTextContainer(container)

        let textView = ZenTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container, theme: theme)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false
        scroll.documentView = textView
        textView.autoresizingMask = [.width]
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(textView, selector: #selector(clipViewDidScroll(_:)),
                                               name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        return (scroll, textView)
    }

    init(frame: NSRect, textContainer: NSTextContainer, theme: EditorTheme) {
        self.theme = theme
        self.styler = MarkdownStyler(theme: theme)
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isEditable = true
        isSelectable = true
        drawsBackground = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        smartInsertDeleteEnabled = false
        isVerticallyResizable = true
        isHorizontallyResizable = false
        minSize = NSSize(width: 0, height: 0)
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textStorage?.delegate = self
        insertionPointColor = .controlAccentColor
        applyTheme()
    }

    // MARK: Theme & layout

    private func applyTheme() {
        styler.theme = theme
        font = theme.font
        typingAttributes = styler.baseAttributes
        defaultParagraphStyle = styler.paragraphStyle()
        selectedTextAttributes = [.backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.22)]
        updateInsets()
        restyleAll()
    }

    func restyleAll() {
        guard let storage = textStorage else { return }
        styler.restyle(storage)
        typingAttributes = styler.baseAttributes
        updateFocusDimming()
        needsDisplay = true
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateInsets()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateInsets()
    }

    private func updateInsets() {
        let width = enclosingScrollView?.contentSize.width ?? bounds.width
        var horizontal = theme.horizontalPadding
        if let max = theme.maxLineWidth, width > max + theme.horizontalPadding * 2 {
            horizontal = ((width - max) / 2).rounded()
        }
        let inset = NSSize(width: horizontal, height: theme.verticalPadding)
        if textContainerInset != inset { textContainerInset = inset }
        if let scroll = enclosingScrollView {
            let bottom = typewriter ? (scroll.contentSize.height * 0.5).rounded() : theme.verticalPadding * 2
            if scroll.contentInsets.bottom != bottom {
                scroll.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
            }
        }
    }

    // MARK: Content

    /// Replaces all text without registering undo (used when switching notes).
    func setText(_ text: String) {
        isProgrammaticChange = true
        string = text
        isProgrammaticChange = false
        undoManager?.removeAllActions(withTarget: self)
        restyleAll()
        setSelectedRange(NSRange(location: 0, length: 0))
        scroll(.zero)
    }

    /// Replaces a range as a single undoable edit.
    func replace(_ range: NSRange, with replacement: String, selection: NSRange? = nil) {
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        if let selection { setSelectedRange(selection) }
    }

    func apply(_ edit: MarkdownEditing.Edit) {
        replace(edit.range, with: edit.replacement, selection: edit.selection)
        scrollRangeToVisible(selectedRange())
    }

    override func didChangeText() {
        super.didChangeText()
        guard !isProgrammaticChange else { return }
        onTextChange?(string)
        updateFocusDimming()
        centerCaret(animated: false)
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        if !stillSelecting {
            updateFocusDimming()
            centerCaret(animated: true)
        }
    }

    // MARK: Placeholder

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let origin = NSPoint(x: textContainerOrigin.x + (textContainer?.lineFragmentPadding ?? 0), y: textContainerOrigin.y)
        (placeholder as NSString).draw(at: origin, withAttributes: [.font: theme.font, .foregroundColor: Palette.dimmed])
    }

    // MARK: Focus & typewriter

    private func updateFocusDimming() {
        guard let layout = layoutManager else { return }
        let ns = string as NSString
        let all = NSRange(location: 0, length: ns.length)
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: all)
        guard focusDimming, ns.length > 0 else { return }
        let focus = paragraphBlock(in: ns, at: min(selectedRange().location, ns.length))
        if focus.location > 0 {
            layout.addTemporaryAttribute(.foregroundColor, value: Palette.dimmed, forCharacterRange: NSRange(location: 0, length: focus.location))
        }
        if NSMaxRange(focus) < ns.length {
            layout.addTemporaryAttribute(.foregroundColor, value: Palette.dimmed, forCharacterRange: NSRange(location: NSMaxRange(focus), length: ns.length - NSMaxRange(focus)))
        }
    }

    /// The paragraph around a location: consecutive non-blank lines.
    private func paragraphBlock(in ns: NSString, at location: Int) -> NSRange {
        func isBlank(_ r: NSRange) -> Bool { ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var range = ns.lineRange(for: NSRange(location: location, length: 0))
        if isBlank(range) { return range }
        while range.location > 0 {
            let prev = ns.lineRange(for: NSRange(location: range.location - 1, length: 0))
            if isBlank(prev) { break }
            range = NSUnionRange(prev, range)
        }
        while NSMaxRange(range) < ns.length {
            let next = ns.lineRange(for: NSRange(location: NSMaxRange(range), length: 0))
            if isBlank(next) { break }
            range = NSUnionRange(range, next)
        }
        return range
    }

    func centerCaret(animated: Bool) {
        guard typewriter, let layout = layoutManager, let container = textContainer,
              let scroll = enclosingScrollView, window != nil else { return }
        let length = (string as NSString).length
        let location = min(selectedRange().location, length)
        var lineRect: NSRect
        if location >= length, !layout.extraLineFragmentRect.isEmpty {
            lineRect = layout.extraLineFragmentRect
        } else {
            layout.ensureLayout(forCharacterRange: NSRange(location: max(0, min(location, length - 1)), length: min(1, length)))
            let glyph = layout.glyphIndexForCharacter(at: max(0, min(location, max(0, length - 1))))
            lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        _ = container
        let clip = scroll.contentView
        let y = lineRect.midY + textContainerOrigin.y - clip.bounds.height / 2
        let target = NSPoint(x: clip.bounds.origin.x, y: max(0, y))
        guard abs(target.y - clip.bounds.origin.y) > 1 else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                clip.animator().setBoundsOrigin(target)
            }
        } else {
            clip.setBoundsOrigin(target)
        }
        scroll.reflectScrolledClipView(clip)
    }

    func scrollToLine(_ line: Int) {
        let ns = string as NSString
        var location = 0
        var current = 1
        while current < line, location < ns.length {
            location = NSMaxRange(ns.lineRange(for: NSRange(location: location, length: 0)))
            current += 1
        }
        setSelectedRange(NSRange(location: min(location, ns.length), length: 0))
        window?.makeFirstResponder(self)
        guard !typewriter, let layout = layoutManager, let scroll = enclosingScrollView else { return }
        let glyph = layout.glyphIndexForCharacter(at: min(location, max(0, ns.length - 1)))
        let rect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let target = NSPoint(x: 0, y: max(0, rect.minY + textContainerOrigin.y - 24))
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scroll.contentView.animator().setBoundsOrigin(target)
        }
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    @objc private func clipViewDidScroll(_ note: Notification) {
        guard let scroll = enclosingScrollView, let doc = scroll.documentView else { return }
        let maxY = doc.frame.height - scroll.contentView.bounds.height
        let fraction = maxY > 0 ? scroll.contentView.bounds.origin.y / maxY : 0
        onScroll?(min(1, max(0, fraction)))
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let ns = string as NSString
        if let storage = textStorage, ns.length > 0 {
            let probe = [index, index - 1].filter { $0 >= 0 && $0 < ns.length }
            if event.modifierFlags.contains(.command) {
                for i in probe {
                    if let link = storage.attribute(.zenLink, at: i, effectiveRange: nil) as? String, let url = URL(string: link), url.scheme != nil {
                        NSWorkspace.shared.open(url)
                        return
                    }
                }
            }
            if isMarkdown, event.clickCount == 1 {
                for i in probe {
                    var range = NSRange()
                    if storage.attribute(.zenTask, at: i, effectiveRange: &range) != nil {
                        let box = NSRange(location: range.location + 1, length: 1)
                        let checked = ns.substring(with: box).lowercased() == "x"
                        replace(box, with: checked ? " " : "x")
                        return
                    }
                }
            }
        }
        super.mouseDown(with: event)
    }

    // MARK: Keys

    override func insertNewline(_ sender: Any?) {
        if isMarkdown, let edit = MarkdownEditing.newline(in: string as NSString, selection: selectedRange()) {
            apply(edit)
            return
        }
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        if isMarkdown, let edit = MarkdownEditing.indent(in: string as NSString, selection: selectedRange(), outdent: false) {
            apply(edit)
            return
        }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if isMarkdown, let edit = MarkdownEditing.indent(in: string as NSString, selection: selectedRange(), outdent: true) {
            apply(edit)
            return
        }
        super.insertBacktab(sender)
    }

    private static let wrapPairs: [String: String] = ["*": "*", "_": "_", "`": "`", "~": "~", "=": "=", "(": ")", "[": "]", "\"": "\"", "<": ">"]

    override func insertText(_ string: Any, replacementRange: NSRange) {
        let sel = selectedRange()
        if isMarkdown, replacementRange.location == NSNotFound, sel.length > 0,
           let typed = string as? String, let close = Self.wrapPairs[typed] {
            let inner = (self.string as NSString).substring(with: sel)
            replace(sel, with: typed + inner + close, selection: NSRange(location: sel.location + 1, length: sel.length))
            return
        }
        super.insertText(string, replacementRange: replacementRange)
    }

    // MARK: Markdown commands (targeted by the Format menu)

    private func wrap(_ marker: String) {
        apply(MarkdownEditing.toggleWrap(in: string as NSString, selection: selectedRange(), marker: marker))
    }

    private func lineStyle(_ style: MarkdownEditing.LineStyle) {
        apply(MarkdownEditing.setLineStyle(in: string as NSString, selection: selectedRange(), style: style))
    }

    @objc func toggleBoldMarkdown(_ sender: Any?) { wrap("**") }
    @objc func toggleItalicMarkdown(_ sender: Any?) { wrap("_") }
    @objc func toggleStrikethroughMarkdown(_ sender: Any?) { wrap("~~") }
    @objc func toggleHighlightMarkdown(_ sender: Any?) { wrap("==") }
    @objc func toggleInlineCodeMarkdown(_ sender: Any?) { wrap("`") }
    @objc func insertLinkMarkdown(_ sender: Any?) { apply(MarkdownEditing.link(in: string as NSString, selection: selectedRange())) }
    @objc func heading1Markdown(_ sender: Any?) { lineStyle(.heading(1)) }
    @objc func heading2Markdown(_ sender: Any?) { lineStyle(.heading(2)) }
    @objc func heading3Markdown(_ sender: Any?) { lineStyle(.heading(3)) }
    @objc func bodyTextMarkdown(_ sender: Any?) { lineStyle(.body) }
    @objc func toggleQuoteMarkdown(_ sender: Any?) { lineStyle(.quote) }
    @objc func toggleBulletListMarkdown(_ sender: Any?) { lineStyle(.bullet) }
    @objc func toggleNumberedListMarkdown(_ sender: Any?) { lineStyle(.numbered) }
    @objc func toggleTaskMarkdown(_ sender: Any?) { lineStyle(.task) }

    @objc func insertCodeBlockMarkdown(_ sender: Any?) {
        let sel = selectedRange()
        let inner = (string as NSString).substring(with: sel)
        let text = "```\n\(inner)\n```"
        replace(sel, with: text, selection: NSRange(location: sel.location + 3, length: 0))
    }

    @objc func insertTableMarkdown(_ sender: Any?) {
        let table = "| Column | Column |\n| ------ | ------ |\n| Cell   | Cell   |\n"
        let sel = selectedRange()
        replace(sel, with: table, selection: NSRange(location: sel.location + 2, length: 6))
    }

    @objc func insertRuleMarkdown(_ sender: Any?) {
        let sel = selectedRange()
        replace(sel, with: "\n---\n", selection: NSRange(location: sel.location + 5, length: 0))
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action.map(NSStringFromSelector) ?? ""
        if action.hasSuffix("Markdown:") { return isEditable && isMarkdown }
        return super.validateMenuItem(menuItem)
    }
}

extension ZenTextView: NSTextStorageDelegate {
    nonisolated func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        MainActor.assumeIsolated {
            styler.restyle(textStorage, edited: editedRange, inEditing: true)
        }
    }
}
