import Foundation
import SwiftUI

// MARK: - Snippet Manager

class SnippetManager: ObservableObject {
    static let shared = SnippetManager()
    
    @Published var snippets: [TextSnippet] = []
    
    private let fileManager = FileManager.default
    
    private var snippetsFile: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ZenPad")
        
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir.appendingPathComponent("snippets.json")
    }
    
    private init() {
        loadSnippets()
        if snippets.isEmpty {
            loadDefaultSnippets()
        }
    }
    
    // MARK: - Default Snippets
    
    private func loadDefaultSnippets() {
        snippets = [
            TextSnippet(trigger: "date", content: "{DATE}", description: "Current date"),
            TextSnippet(trigger: "time", content: "{TIME}", description: "Current time"),
            TextSnippet(trigger: "dt", content: "{DATETIME}", description: "Date and time"),
            TextSnippet(trigger: "sig", content: "Best regards,\n{CURSOR}", description: "Email signature"),
            TextSnippet(trigger: "todo", content: "- [ ] {CURSOR}", description: "Todo item"),
            TextSnippet(trigger: "cb", content: "```\n{CURSOR}\n```", description: "Code block"),
            TextSnippet(trigger: "link", content: "[{CURSOR}](url)", description: "Markdown link"),
            TextSnippet(trigger: "img", content: "![alt]({CURSOR})", description: "Markdown image"),
            TextSnippet(trigger: "h1", content: "# {CURSOR}", description: "Heading 1"),
            TextSnippet(trigger: "h2", content: "## {CURSOR}", description: "Heading 2"),
            TextSnippet(trigger: "h3", content: "### {CURSOR}", description: "Heading 3"),
            TextSnippet(trigger: "bold", content: "**{CURSOR}**", description: "Bold text"),
            TextSnippet(trigger: "italic", content: "*{CURSOR}*", description: "Italic text"),
            TextSnippet(trigger: "table", content: """
                | Column 1 | Column 2 | Column 3 |
                |----------|----------|----------|
                | {CURSOR} |          |          |
                """, description: "Markdown table"),
            TextSnippet(trigger: "note", content: "> **Note:** {CURSOR}", description: "Note callout"),
            TextSnippet(trigger: "lorem", content: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", description: "Lorem ipsum")
        ]
        saveSnippets()
    }
    
    // MARK: - Persistence
    
    private func loadSnippets() {
        guard fileManager.fileExists(atPath: snippetsFile.path),
              let data = try? Data(contentsOf: snippetsFile),
              let loaded = try? JSONDecoder().decode([TextSnippet].self, from: data) else {
            return
        }
        snippets = loaded
    }
    
    private func saveSnippets() {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: snippetsFile)
        }
    }
    
    // MARK: - CRUD
    
    func addSnippet(_ snippet: TextSnippet) {
        snippets.append(snippet)
        saveSnippets()
    }
    
    func updateSnippet(_ snippet: TextSnippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
        }
    }
    
    func deleteSnippet(_ snippet: TextSnippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveSnippets()
    }
    
    // MARK: - Expansion
    
    func expand(_ trigger: String) -> String? {
        guard let snippet = snippets.first(where: { $0.trigger == trigger }) else {
            return nil
        }
        return expandVariables(in: snippet.content)
    }
    
    func snippetFor(trigger: String) -> TextSnippet? {
        snippets.first { $0.trigger == trigger }
    }
    
    private func expandVariables(in content: String) -> String {
        var result = content
        
        // Date variables
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        result = result.replacingOccurrences(of: "{DATE}", with: dateFormatter.string(from: Date()))
        
        // Time variables
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{TIME}", with: timeFormatter.string(from: Date()))
        
        // DateTime
        let dtFormatter = DateFormatter()
        dtFormatter.dateStyle = .medium
        dtFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{DATETIME}", with: dtFormatter.string(from: Date()))
        
        // Cursor placeholder - remove it (actual cursor positioning would need NSTextView integration)
        result = result.replacingOccurrences(of: "{CURSOR}", with: "")
        
        return result
    }
    
    func matchingSnippets(for text: String) -> [TextSnippet] {
        let words = text.components(separatedBy: .whitespaces)
        guard let lastWord = words.last, !lastWord.isEmpty else { return [] }
        
        return snippets.filter { $0.trigger.hasPrefix(lastWord) }
    }
}

// MARK: - Snippet Model

struct TextSnippet: Identifiable, Codable, Hashable {
    let id: UUID
    var trigger: String
    var content: String
    var description: String
    
    init(id: UUID = UUID(), trigger: String, content: String, description: String) {
        self.id = id
        self.trigger = trigger
        self.content = content
        self.description = description
    }
}

// MARK: - Snippet Manager View

struct SnippetManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var snippetManager = SnippetManager.shared
    @State private var selectedSnippet: TextSnippet?
    @State private var isEditing = false
    @State private var editingSnippet: TextSnippet?
    
    var body: some View {
        HSplitView {
            // Snippet list
            VStack(spacing: 0) {
                List(selection: $selectedSnippet) {
                    ForEach(snippetManager.snippets) { snippet in
                        SnippetRow(snippet: snippet)
                            .tag(snippet)
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                HStack {
                    Button(action: addSnippet) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: deleteSelected) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedSnippet == nil)
                    
                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 200)
            
            // Detail view
            if let snippet = selectedSnippet {
                SnippetDetailView(
                    snippet: Binding(
                        get: { snippet },
                        set: { snippetManager.updateSnippet($0) }
                    )
                )
            } else {
                VStack {
                    Image(systemName: "text.snippet")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a snippet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 600, height: 400)
    }
    
    private func addSnippet() {
        let newSnippet = TextSnippet(trigger: "new", content: "", description: "New Snippet")
        snippetManager.addSnippet(newSnippet)
        selectedSnippet = newSnippet
    }
    
    private func deleteSelected() {
        if let snippet = selectedSnippet {
            snippetManager.deleteSnippet(snippet)
            selectedSnippet = nil
        }
    }
}

struct SnippetRow: View {
    let snippet: TextSnippet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(snippet.trigger)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.accentColor)
                
                Spacer()
            }
            
            Text(snippet.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct SnippetDetailView: View {
    @Binding var snippet: TextSnippet
    
    var body: some View {
        Form {
            Section("Trigger") {
                TextField("Trigger", text: $snippet.trigger)
                    .font(.system(.body, design: .monospaced))
                
                Text("Type this text to expand the snippet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Description") {
                TextField("Description", text: $snippet.description)
            }
            
            Section("Content") {
                TextEditor(text: $snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                
                Text("Use {DATE}, {TIME}, {DATETIME}, {CURSOR} for variables")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Preview") {
                Text(SnippetManager.shared.expand(snippet.trigger) ?? snippet.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding()
    }
}

#Preview {
    SnippetManagerView()
}
