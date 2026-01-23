import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var lineHeight: CGFloat
    var textColor: NSColor
    var backgroundColor: NSColor
    var onTextChange: ((String) -> Void)?
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ZenTextView()
        
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = backgroundColor
        
        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.font = font
        textView.insertionPointColor = textColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor
        ]
        
        // Typography settings
        textView.textContainerInset = NSSize(width: 40, height: 30)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        
        // Line height
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = lineHeight
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        // Configure text container
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        
        // Set initial text
        textView.string = text
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Update colors for theme changes
        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        
        // Update font if changed
        if textView.font != font {
            textView.font = font
        }
        
        // Only update text if it differs (to preserve cursor position)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        private var debounceTimer: Timer?
        
        init(_ parent: EditorView) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Debounce updates
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.parent.text = textView.string
                    self?.parent.onTextChange?(textView.string)
                }
            }
        }
    }
}

// Custom NSTextView subclass for additional features
class ZenTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle custom key bindings if needed
        return super.performKeyEquivalent(with: event)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }
}

#Preview {
    EditorView(
        text: .constant("Hello, ZenPad!"),
        font: .monospacedSystemFont(ofSize: 14, weight: .regular),
        lineHeight: 1.5,
        textColor: .textColor,
        backgroundColor: .textBackgroundColor
    )
}
