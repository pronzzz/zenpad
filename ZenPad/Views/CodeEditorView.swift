import SwiftUI
import AppKit

// MARK: - Code Editor View with Line Numbers and Syntax Highlighting

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: SyntaxHighlighter.Language
    var isDarkMode: Bool
    var font: NSFont
    var showLineNumbers: Bool
    var onTextChange: ((String) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CodeScrollView()
        let textView = CodeTextView()
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        
        // Typography
        textView.font = font
        textView.textContainerInset = NSSize(width: showLineNumbers ? 50 : 20, height: 15)
        
        // Disable automatic substitutions for code
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        
        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        
        // Configure ruler for line numbers
        if showLineNumbers {
            scrollView.rulersVisible = true
            scrollView.hasVerticalRuler = true
            let lineNumberView = LineNumberRulerView(textView: textView)
            scrollView.verticalRulerView = lineNumberView
        }
        
        scrollView.documentView = textView
        
        // Store reference for updates
        context.coordinator.textView = textView
        context.coordinator.lineNumberView = scrollView.verticalRulerView as? LineNumberRulerView
        
        // Apply initial content
        applyHighlighting(to: textView, context: context)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeTextView else { return }
        
        // Update theme
        let theme = isDarkMode ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
        scrollView.backgroundColor = theme.background
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.foreground
        
        // Update line numbers
        if let lineNumberView = scrollView.verticalRulerView as? LineNumberRulerView {
            lineNumberView.textColor = theme.comment
            lineNumberView.backgroundColor = theme.background
            lineNumberView.needsDisplay = true
        }
        
        // Only update if text changed externally
        if textView.string != text {
            applyHighlighting(to: textView, context: context)
        }
    }
    
    private func applyHighlighting(to textView: NSTextView, context: Context) {
        let theme = isDarkMode ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
        let attributedText = SyntaxHighlighter.shared.highlight(text, language: language, theme: theme)
        
        // Preserve selection
        let selectedRanges = textView.selectedRanges
        
        textView.textStorage?.setAttributedString(attributedText)
        
        // Restore selection
        textView.selectedRanges = selectedRanges
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: NSTextView?
        weak var lineNumberView: LineNumberRulerView?
        private var debounceTimer: Timer?
        
        init(_ parent: CodeEditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Update line numbers
            lineNumberView?.needsDisplay = true
            
            // Debounce syntax highlighting and binding update
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let newText = textView.string
                    self.parent.text = newText
                    self.parent.onTextChange?(newText)
                    
                    // Re-apply syntax highlighting
                    self.applyHighlighting()
                }
            }
        }
        
        private func applyHighlighting() {
            guard let textView = textView else { return }
            let theme = parent.isDarkMode ? SyntaxHighlighter.Theme.dark : SyntaxHighlighter.Theme.light
            
            // Get current selection
            let selectedRanges = textView.selectedRanges
            
            // Apply highlighting
            let attributedText = SyntaxHighlighter.shared.highlight(textView.string, language: parent.language, theme: theme)
            textView.textStorage?.setAttributedString(attributedText)
            
            // Restore selection
            textView.selectedRanges = selectedRanges
        }
        
        // MARK: - Bracket Matching
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            highlightMatchingBrackets(in: textView)
        }
        
        private func highlightMatchingBrackets(in textView: NSTextView) {
            let brackets: [(open: Character, close: Character)] = [
                ("(", ")"),
                ("[", "]"),
                ("{", "}")
            ]
            
            guard let textStorage = textView.textStorage else { return }
            let text = textView.string
            let cursorPosition = textView.selectedRange().location
            
            guard cursorPosition > 0 && cursorPosition <= text.count else { return }
            
            let index = text.index(text.startIndex, offsetBy: cursorPosition - 1, limitedBy: text.endIndex) ?? text.startIndex
            let charAtCursor = text[index]
            
            // Check if character is a bracket
            for bracket in brackets {
                if charAtCursor == bracket.close {
                    if let matchIndex = findMatchingOpenBracket(in: text, from: cursorPosition - 1, bracket: bracket) {
                        // Highlight matching bracket
                        textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: NSRange(location: matchIndex, length: 1))
                        textStorage.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: NSRange(location: cursorPosition - 1, length: 1))
                        
                        // Remove highlight after short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: matchIndex, length: 1))
                            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: cursorPosition - 1, length: 1))
                        }
                    }
                }
            }
        }
        
        private func findMatchingOpenBracket(in text: String, from position: Int, bracket: (open: Character, close: Character)) -> Int? {
            var depth = 1
            var currentPos = position - 1
            
            while currentPos >= 0 {
                let index = text.index(text.startIndex, offsetBy: currentPos)
                let char = text[index]
                
                if char == bracket.close {
                    depth += 1
                } else if char == bracket.open {
                    depth -= 1
                    if depth == 0 {
                        return currentPos
                    }
                }
                currentPos -= 1
            }
            
            return nil
        }
        
        // MARK: - Auto-Close Brackets
        
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString, replacement.count == 1 else { return true }
            
            let brackets: [Character: Character] = [
                "(": ")",
                "[": "]",
                "{": "}",
                "\"": "\"",
                "'": "'"
            ]
            
            if let char = replacement.first, let closingBracket = brackets[char] {
                // Insert both opening and closing brackets
                let insertText = "\(char)\(closingBracket)"
                textView.insertText(insertText, replacementRange: affectedCharRange)
                
                // Move cursor between brackets
                let newPosition = affectedCharRange.location + 1
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
                
                return false
            }
            
            return true
        }
    }
}

// MARK: - Custom NSTextView

class CodeTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+/ for commenting
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "/" {
            toggleComment()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    
    private func toggleComment() {
        guard let textStorage = textStorage else { return }
        let selectedRange = self.selectedRange()
        let text = self.string as NSString
        
        // Get line range
        let lineRange = text.lineRange(for: selectedRange)
        let lineText = text.substring(with: lineRange)
        
        let trimmedLine = lineText.trimmingCharacters(in: .whitespaces)
        
        if trimmedLine.hasPrefix("//") {
            // Uncomment
            if let range = lineText.range(of: "// ") ?? lineText.range(of: "//") {
                let nsRange = NSRange(range, in: lineText)
                let absoluteRange = NSRange(location: lineRange.location + nsRange.location, length: nsRange.length)
                textStorage.replaceCharacters(in: absoluteRange, with: "")
            }
        } else {
            // Comment
            let insertRange = NSRange(location: lineRange.location, length: 0)
            textStorage.replaceCharacters(in: insertRange, with: "// ")
        }
    }
}

// MARK: - Custom Scroll View

class CodeScrollView: NSScrollView {
    override var isFlipped: Bool { true }
}

// MARK: - Line Number Ruler View

class LineNumberRulerView: NSRulerView {
    var textColor: NSColor = .secondaryLabelColor
    var backgroundColor: NSColor = .clear
    
    weak var textView: NSTextView?
    
    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        
        self.clientView = textView
        self.ruleThickness = 40
        
        // Observe text changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func textDidChange(_ notification: Notification) {
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.set()
        dirtyRect.fill()
        
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        let text = textView.string as NSString
        let visibleRect = scrollView?.documentVisibleRect ?? bounds
        
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]
        
        var lineNumber = 1
        var glyphIndex = 0
        
        while glyphIndex < layoutManager.numberOfGlyphs {
            let charRange = layoutManager.characterRange(forGlyphRange: NSRange(location: glyphIndex, length: 1), actualGlyphRange: nil)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            
            let yPosition = lineRect.origin.y + textView.textContainerInset.height - visibleRect.origin.y
            
            if yPosition >= -lineRect.height && yPosition <= visibleRect.height + lineRect.height {
                let lineNumberString = "\(lineNumber)"
                let stringSize = lineNumberString.size(withAttributes: attributes)
                let point = NSPoint(x: ruleThickness - stringSize.width - 8, y: yPosition + (lineRect.height - stringSize.height) / 2)
                lineNumberString.draw(at: point, withAttributes: attributes)
            }
            
            // Find next line
            let lineEnd = text.lineRange(for: charRange).upperBound
            if lineEnd >= text.length {
                break
            }
            
            glyphIndex = layoutManager.glyphIndexForCharacter(at: lineEnd)
            lineNumber += 1
        }
    }
}

#Preview {
    CodeEditorView(
        text: .constant("""
        func hello() {
            print("Hello, World!")
        }
        """),
        language: .swift,
        isDarkMode: false,
        font: .monospacedSystemFont(ofSize: 14, weight: .regular),
        showLineNumbers: true
    )
}
