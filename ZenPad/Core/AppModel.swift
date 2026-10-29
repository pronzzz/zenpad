import AppKit
import Combine
import UniformTypeIdentifiers

/// App-wide UI state and the actions menus, shortcuts and views share.
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let prefs = Prefs.shared
    let library = Library.shared
    let session = EditorSession.shared

    @Published var focusMode = false
    @Published var showAI = false
    @Published var showTemplates = false
    @Published var searchFocusToken = 0

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        // Re-publish nested objects so views observing AppModel refresh.
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        library.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    // MARK: Notes

    /// Makes sure something is open: the most recent note, or a welcome note on first run.
    func ensureSelection() {
        guard session.note == nil else { return }
        if let first = library.notes.first {
            session.open(first)
        } else {
            session.open(library.createNote(content: WelcomeNote.text))
        }
    }

    func select(_ note: Note) {
        session.open(note)
    }

    @discardableResult
    func newNote(content: String = "") -> Note {
        let note = library.createNote(content: content)
        session.open(note)
        library.searchText = ""
        return note
    }

    func newNote(from template: NoteTemplate) {
        newNote(content: template.expanded())
        showTemplates = false
        DispatchQueue.main.async { [weak self] in
            guard let tv = self?.session.textView else { return }
            tv.window?.makeFirstResponder(tv)
            let end = (tv.string as NSString).length
            tv.setSelectedRange(NSRange(location: end, length: 0))
        }
    }

    func open(url: URL) {
        let note = library.openExternal(url)
        session.open(note)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        MainWindowController.shared.show()
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { open(url: url) }
    }

    func saveAs() {
        guard let note = session.note else { return }
        session.saveNow()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = note.url.lastPathComponent
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try session.text.write(to: url, atomically: true, encoding: .utf8)
            open(url: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    func duplicate(_ note: Note) {
        session.saveNow()
        if let copy = library.duplicate(note) { session.open(copy) }
    }

    func moveToTrash(_ note: Note) {
        let wasOpen = session.note?.url == note.url
        if wasOpen {
            session.saveNow()
            let next = library.notes.first { $0.url != note.url }
            if let next { session.open(next) } else { session.close() }
        }
        library.moveToTrash(note)
    }

    func reveal(_ note: Note) {
        NSWorkspace.shared.activateFileViewerSelecting([note.url])
    }

    // MARK: View state

    func setMode(_ mode: EditorMode) {
        prefs.editorMode = mode
    }

    func cycleMode() {
        let all = EditorMode.allCases
        let index = all.firstIndex(of: prefs.editorMode) ?? 0
        setMode(all[(index + 1) % all.count])
    }

    func toggleSidebar() {
        prefs.showSidebar.toggle()
    }

    func toggleFocus() {
        focusMode.toggle()
        if focusMode, prefs.editorMode == .preview { prefs.editorMode = .write }
    }

    func focusSearch() {
        if !prefs.showSidebar { prefs.showSidebar = true }
        searchFocusToken += 1
    }
}

/// The note created on first launch. It doubles as a tour of what ZenPad renders.
enum WelcomeNote {
    static let text = """
    # Welcome to ZenPad

    ZenPad is a quiet place to write. Notes are plain **Markdown** files in your library folder, saved as you type.

    ## Three ways in

    - Click the ensō in the menu bar for the **Quick Pad**
    - Press **⌃⌥N** anywhere to jot something down
    - Press **⌃⌥Z** to open this editor

    ## Markdown, all of it

    Write *italic*, **bold**, ~~strikethrough~~, `inline code` and [links](https://github.com/pronzzz/zenpad).

    - [x] Task lists you can tick in the editor or the preview
    - [ ] Tables, footnotes[^1] and GitHub alerts
    - [ ] Fenced code with syntax highlighting

    > [!TIP]
    > Press **⌘2** for a live side-by-side preview, and **⇧⌘F** for focus mode.

    | Shortcut | Action |
    | -------- | ------ |
    | ⌘B / ⌘I | Bold / italic |
    | ⌘K | Link |
    | ⇧⌘T | Toggle task |

    ```swift
    let thought = "Write it down."
    print(thought)
    ```

    [^1]: Footnotes are collected at the bottom of the preview.
    """
}
