import AppKit
import Combine

/// The note open in the main window. The text view is the source of truth while typing;
/// the session mirrors its text, autosaves, and keeps the library list fresh.
final class EditorSession: ObservableObject {
    static let shared = EditorSession()

    @Published private(set) var note: Note?
    @Published private(set) var text = ""
    @Published private(set) var stats = TextStats()
    @Published private(set) var isDirty = false
    @Published private(set) var lastTyped = Date.distantPast
    @Published var scrollFraction: CGFloat = 0

    weak var textView: ZenTextView?

    private var pendingSave: DispatchWorkItem?
    private var pendingStats: DispatchWorkItem?
    private var loadedModified: Date?

    var isMarkdown: Bool { note?.isMarkdown ?? true }
    var headings: [(level: Int, title: String, line: Int)] { MarkdownEditing.headings(in: text) }

    func attach(_ textView: ZenTextView) {
        self.textView = textView
        textView.isMarkdown = isMarkdown
        if textView.string != text { textView.setText(text) }
        textView.onTextChange = { [weak self] newText in self?.textDidChange(newText) }
        textView.onScroll = { [weak self] fraction in
            guard let self, abs(self.scrollFraction - fraction) > 0.002 else { return }
            self.scrollFraction = fraction
        }
    }

    // MARK: Opening

    func open(_ note: Note) {
        if note.url == self.note?.url { return }
        saveNow()
        let content = (try? String(contentsOf: note.url, encoding: .utf8)) ?? ""
        self.note = note
        text = content
        isDirty = false
        loadedModified = modificationDate(note.url)
        stats = TextStats(content)
        textView?.isMarkdown = note.isMarkdown
        textView?.setText(content)
    }

    func close() {
        saveNow()
        note = nil
        text = ""
        stats = TextStats()
        textView?.setText("")
    }

    /// Picks up edits made by other apps (or iCloud) while ZenPad was in the background.
    func reloadIfChangedOnDisk() {
        guard let note, !isDirty, let modified = modificationDate(note.url), let loaded = loadedModified, modified > loaded else { return }
        guard let content = try? String(contentsOf: note.url, encoding: .utf8), content != text else { return }
        text = content
        loadedModified = modified
        stats = TextStats(content)
        let selection = textView?.selectedRange()
        textView?.setText(content)
        if let selection, selection.location <= (content as NSString).length { textView?.setSelectedRange(selection) }
    }

    // MARK: Editing

    private func textDidChange(_ newText: String) {
        text = newText
        isDirty = true
        lastTyped = Date()
        scheduleStats()
        scheduleSave()
    }

    /// Replaces the whole text as one undoable edit (used by the AI assistant and preview checkboxes).
    func replaceAll(with newText: String) {
        guard let textView else { return }
        textView.replace(NSRange(location: 0, length: (textView.string as NSString).length), with: newText)
    }

    func toggleTask(line: Int) {
        guard let updated = MarkdownEditing.toggleTask(in: text, line: line) else { return }
        replaceAll(with: updated)
    }

    private func scheduleStats() {
        pendingStats?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.stats = TextStats(self.text)
        }
        pendingStats = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    // MARK: Saving

    func saveNow() {
        pendingSave?.cancel()
        guard isDirty, var note else { return }
        do {
            try text.write(to: note.url, atomically: true, encoding: .utf8)
            isDirty = false
            let renamed = Library.shared.renameIfNeeded(note.url, text: text)
            if renamed != note.url {
                note.url = renamed
                self.note = note
            }
            loadedModified = modificationDate(note.url)
            Library.shared.didSave(url: note.url, text: text)
            if let updated = Library.shared.note(at: note.url) { self.note = updated }
        } catch {
            NSSound.beep()
            let alert = NSAlert(error: error)
            alert.messageText = "ZenPad couldn't save “\(note.title)”."
            alert.runModal()
        }
    }

    private func modificationDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
