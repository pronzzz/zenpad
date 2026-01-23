import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Menu Bar Controller

class MenuBarController: NSObject, ObservableObject {
    static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    @Published var quickNoteText = ""
    @Published var isPopoverShown = false
    
    private override init() {
        super.init()
    }
    
    func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "ZenPad Quick Note")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: QuickNoteView())
    }
    
    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
            isPopoverShown = false
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isPopoverShown = true
            
            // Focus the text field
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showPopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isPopoverShown = true
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func hidePopover() {
        popover?.performClose(nil)
        isPopoverShown = false
    }
}

// MARK: - Quick Note View

struct QuickNoteView: View {
    @StateObject private var menuBarController = MenuBarController.shared
    @State private var noteText = ""
    @State private var savedNotes: [QuickNote] = []
    @FocusState private var isTextFieldFocused: Bool
    
    struct QuickNote: Identifiable, Codable {
        let id: UUID
        let text: String
        let createdAt: Date
        
        init(text: String) {
            self.id = UUID()
            self.text = text
            self.createdAt = Date()
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.accentColor)
                Text("Quick Note")
                    .font(.headline)
                Spacer()
                
                Button(action: { openMainApp() }) {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .help("Open in ZenPad")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Text input
            VStack(spacing: 8) {
                TextEditor(text: $noteText)
                    .font(.system(size: 13))
                    .frame(minHeight: 120)
                    .focused($isTextFieldFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                
                HStack {
                    Text("\(noteText.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Clear") {
                        noteText = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(noteText.isEmpty)
                    
                    Button("Save") {
                        saveNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            
            Divider()
            
            // Recent notes
            if !savedNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(savedNotes.prefix(5)) { note in
                                QuickNoteRow(note: note) {
                                    noteText = note.text
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
        .frame(width: 320, height: 400)
        .onAppear {
            isTextFieldFocused = true
            loadSavedNotes()
        }
    }
    
    private func saveNote() {
        let note = QuickNote(text: noteText)
        savedNotes.insert(note, at: 0)
        
        // Keep only last 20 notes
        if savedNotes.count > 20 {
            savedNotes = Array(savedNotes.prefix(20))
        }
        
        saveNotesToDisk()
        noteText = ""
    }
    
    private func loadSavedNotes() {
        let url = getNotesFileURL()
        
        if let data = try? Data(contentsOf: url),
           let notes = try? JSONDecoder().decode([QuickNote].self, from: data) {
            savedNotes = notes
        }
    }
    
    private func saveNotesToDisk() {
        let url = getNotesFileURL()
        
        if let data = try? JSONEncoder().encode(savedNotes) {
            try? data.write(to: url)
        }
    }
    
    private func getNotesFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let zenPadDir = appSupport.appendingPathComponent("ZenPad")
        
        if !FileManager.default.fileExists(atPath: zenPadDir.path) {
            try? FileManager.default.createDirectory(at: zenPadDir, withIntermediateDirectories: true)
        }
        
        return zenPadDir.appendingPathComponent("quick_notes.json")
    }
    
    private func openMainApp() {
        // Create a new document with the quick note text
        if !noteText.isEmpty {
            DocumentManager.shared.createNewDocument()
            if let docId = DocumentManager.shared.currentDocumentId {
                DocumentManager.shared.updateContent(noteText, for: docId)
            }
        }
        
        // Bring main window to front
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first(where: { $0.title.contains("ZenPad") || $0.title.isEmpty }) {
            window.makeKeyAndOrderFront(nil)
        }
        
        MenuBarController.shared.hidePopover()
    }
}

struct QuickNoteRow: View {
    let note: QuickNoteView.QuickNote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.text.prefix(50))
                        .lineLimit(1)
                        .font(.system(size: 12))
                    
                    Text(note.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuickNoteView()
}
