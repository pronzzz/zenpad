import SwiftUI

/// SwiftUI wrapper for the main editor. The text view is created once and kept alive across
/// mode switches; content changes go through `EditorSession`.
struct EditorView: NSViewRepresentable {
    @ObservedObject var prefs: Prefs
    var session: EditorSession
    var focusMode: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let (scroll, textView) = ZenTextView.makeScrollable(theme: .main(from: prefs))
        configure(textView)
        session.attach(textView)
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? ZenTextView else { return }
        configure(textView)
    }

    private func configure(_ textView: ZenTextView) {
        textView.theme = .main(from: prefs)
        textView.isContinuousSpellCheckingEnabled = prefs.spellCheck
        textView.typewriter = prefs.typewriterScrolling
        textView.focusDimming = focusMode && prefs.focusDimming
        textView.styleMarkdown = prefs.styleMarkdown
    }
}
