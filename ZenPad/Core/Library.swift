import AppKit
import Combine

/// A note is a plain Markdown (or text) file on disk.
struct Note: Identifiable, Hashable {
    var url: URL
    var title: String
    var snippet: String
    var modified: Date
    var isExternal: Bool

    var id: URL { url }
    var isMarkdown: Bool { url.pathExtension.lowercased() != "txt" }
}

/// The notes folder (default ~/Documents/ZenPad) plus any files opened from elsewhere.
/// Pick a folder inside iCloud Drive in Settings to sync notes across Macs.
final class Library: ObservableObject {
    static let shared = Library()

    @Published private(set) var notes: [Note] = []
    @Published private(set) var externalNotes: [Note] = []
    @Published var searchText = ""

    static let noteExtensions: Set<String> = ["md", "markdown", "mdown", "txt"]

    private(set) var folderURL: URL
    private var contents: [URL: String] = [:]
    private var watcher: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    private init() {
        folderURL = URL(fileURLWithPath: Prefs.shared.libraryPath, isDirectory: true)
        if let demo = Runtime.value(for: "--library") {
            folderURL = URL(fileURLWithPath: demo, isDirectory: true)
        }
    }

    // MARK: Folder

    func start() {
        ensureFolder()
        reload()
        watch()
    }

    func moveLibrary(to url: URL) {
        Prefs.shared.libraryPath = url.path
        folderURL = url
        start()
    }

    private func ensureFolder() {
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    private func watch() {
        watcher?.cancel()
        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.scheduleReload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    func scheduleReload() {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reload() }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Re-reads the folder. Notes are small, so their text is cached for search.
    func reload() {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var loaded: [Note] = []
        var newContents: [URL: String] = [:]
        for url in urls where Library.noteExtensions.contains(url.pathExtension.lowercased()) {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            newContents[url.standardizedFileURL] = text
            loaded.append(Library.makeNote(url: url, text: text, modified: values?.contentModificationDate ?? .distantPast, external: false))
        }
        contents = newContents.merging(contents.filter { key, _ in externalNotes.contains { $0.url == key } }) { new, _ in new }
        loaded.sort { $0.modified > $1.modified }
        if loaded != notes { notes = loaded }
    }

    // MARK: Queries

    var filteredNotes: [Note] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return notes }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(query)
                || (contents[note.url.standardizedFileURL]?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func note(at url: URL) -> Note? {
        let key = url.standardizedFileURL
        return notes.first { $0.url.standardizedFileURL == key } ?? externalNotes.first { $0.url.standardizedFileURL == key }
    }

    func isInLibrary(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL.path == folderURL.standardizedFileURL.path
    }

    // MARK: Changes

    @discardableResult
    func createNote(content: String = "") -> Note {
        ensureFolder()
        let title = Library.title(from: content, fallback: "Untitled")
        let url = uniqueURL(for: title)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        let note = Library.makeNote(url: url, text: content, modified: Date(), external: false)
        contents[url.standardizedFileURL] = content
        notes.insert(note, at: 0)
        return note
    }

    /// Called after the editor saves, so the list updates immediately without waiting for the file watcher.
    func didSave(url: URL, text: String) {
        contents[url.standardizedFileURL] = text
        let updated = Library.makeNote(url: url, text: text, modified: Date(), external: !isInLibrary(url))
        if let index = notes.firstIndex(where: { $0.url == url }) {
            notes.remove(at: index)
            notes.insert(updated, at: 0)
        } else if let index = externalNotes.firstIndex(where: { $0.url == url }) {
            externalNotes[index] = updated
        }
    }

    /// Renames a library note's file to match its title. Returns the new URL (or the old one if unchanged).
    func renameIfNeeded(_ url: URL, text: String) -> URL {
        guard isInLibrary(url) else { return url }
        let title = Library.title(from: text, fallback: "Untitled")
        let desired = Library.fileName(for: title)
        let current = url.deletingPathExtension().lastPathComponent
        guard desired != current, !Library.hasNumberSuffix(current, base: desired) else { return url }
        let target = uniqueURL(for: title, ext: url.pathExtension)
        do {
            try FileManager.default.moveItem(at: url, to: target)
            if let index = notes.firstIndex(where: { $0.url == url }) { notes[index].url = target }
            contents[target.standardizedFileURL] = contents.removeValue(forKey: url.standardizedFileURL)
            return target
        } catch {
            return url
        }
    }

    func openExternal(_ url: URL) -> Note {
        if let existing = note(at: url) { return existing }
        if isInLibrary(url) {
            reload()
            if let existing = note(at: url) { return existing }
        }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
        let note = Library.makeNote(url: url, text: text, modified: modified, external: true)
        contents[url.standardizedFileURL] = text
        externalNotes.insert(note, at: 0)
        return note
    }

    func closeExternal(_ note: Note) {
        externalNotes.removeAll { $0.url == note.url }
    }

    func duplicate(_ note: Note) -> Note? {
        guard let text = try? String(contentsOf: note.url, encoding: .utf8) else { return nil }
        let url = uniqueURL(for: note.title + " copy", ext: note.url.pathExtension)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        reload()
        return self.note(at: url)
    }

    func moveToTrash(_ note: Note) {
        NSWorkspace.shared.recycle([note.url]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.notes.removeAll { $0.url == note.url }
                self?.externalNotes.removeAll { $0.url == note.url }
            }
        }
    }

    // MARK: Helpers

    private func uniqueURL(for title: String, ext: String = "md") -> URL {
        let base = Library.fileName(for: title)
        var candidate = folderURL.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }

    static func hasNumberSuffix(_ name: String, base: String) -> Bool {
        guard name.hasPrefix(base + " ") else { return false }
        return Int(name.dropFirst(base.count + 1)) != nil
    }

    static func makeNote(url: URL, text: String, modified: Date, external: Bool) -> Note {
        let fallback = url.deletingPathExtension().lastPathComponent
        return Note(url: url, title: title(from: text, fallback: fallback), snippet: snippet(from: text), modified: modified, isExternal: external)
    }

    /// The first non-empty line, without Markdown heading marks or emphasis.
    static func title(from text: String, fallback: String) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).makeIterator()
        var inFrontMatter = false
        var first = true
        while let raw = lines.next() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if first && line == "---" { inFrontMatter = true; first = false; continue }
            first = false
            if inFrontMatter { if line == "---" { inFrontMatter = false }; continue }
            guard !line.isEmpty else { continue }
            let cleaned = stripInlineMarkdown(line.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression))
            let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            return String(trimmed.prefix(80))
        }
        return fallback
    }

    static func snippet(from text: String) -> String {
        var lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") { lines.removeSubrange(0...end) }
        let body = lines.dropFirst().prefix(6)
            .filter { !$0.hasPrefix("```") && $0 != "---" }
            .map { stripInlineMarkdown($0.replacingOccurrences(of: "^(#{1,6}|>|[-*+]( \\[[ xX]\\])?|\\d+[.)])\\s+", with: "", options: .regularExpression)) }
            .joined(separator: " ")
        return String(body.prefix(140))
    }

    nonisolated static func stripInlineMarkdown(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "!?\\[([^\\]]*)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: "[*_~`]+", with: "", options: .regularExpression)
        return t
    }

    static func fileName(for title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        var name = title.components(separatedBy: illegal).joined(separator: " ")
        name = name.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        while name.hasPrefix(".") { name.removeFirst() }
        if name.isEmpty { name = "Untitled" }
        return String(name.prefix(60)).trimmingCharacters(in: .whitespaces)
    }
}

/// Word and character counts for the status bar.
struct TextStats: Equatable {
    var words = 0
    var characters = 0
    var readingMinutes = 0

    init() {}

    init(_ text: String) {
        var count = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            let isLetter = CharacterSet.alphanumerics.contains(scalar)
            if isLetter && !inWord { count += 1 }
            inWord = isLetter || (inWord && (scalar == "'" || scalar == "’"))
        }
        words = count
        characters = text.count
        readingMinutes = max(1, Int((Double(count) / 230).rounded(.up)))
    }

    var readingTime: String { words == 0 ? "0 min" : "\(readingMinutes) min read" }
}
