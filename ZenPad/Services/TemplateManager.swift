import Foundation
import SwiftUI

// MARK: - Template Manager

class TemplateManager: ObservableObject {
    static let shared = TemplateManager()
    
    @Published var templates: [DocumentTemplate] = []
    @Published var customTemplates: [DocumentTemplate] = []
    
    private let fileManager = FileManager.default
    
    private var templatesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ZenPad/templates", isDirectory: true)
        
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        return dir
    }
    
    private init() {
        loadBuiltInTemplates()
        loadCustomTemplates()
    }
    
    // MARK: - Built-in Templates
    
    private func loadBuiltInTemplates() {
        templates = [
            DocumentTemplate(
                id: UUID(),
                name: "Blank",
                description: "Start with an empty document",
                icon: "doc",
                content: "",
                fileType: .plainText,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "Meeting Notes",
                description: "Template for meeting notes with attendees and action items",
                icon: "person.3",
                content: """
                # Meeting Notes
                
                **Date:** \(Date().formatted(date: .abbreviated, time: .shortened))
                **Attendees:** 
                
                ---
                
                ## Agenda
                
                1. 
                2. 
                3. 
                
                ---
                
                ## Discussion
                
                
                
                ---
                
                ## Action Items
                
                - [ ] 
                - [ ] 
                - [ ] 
                
                ---
                
                ## Next Steps
                
                
                """,
                fileType: .markdown,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "To-Do List",
                description: "Simple task list with checkboxes",
                icon: "checklist",
                content: """
                # To-Do List
                
                ## High Priority
                - [ ] 
                - [ ] 
                
                ## Medium Priority
                - [ ] 
                - [ ] 
                
                ## Low Priority
                - [ ] 
                - [ ] 
                
                ---
                
                **Notes:**
                
                
                """,
                fileType: .markdown,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "Blog Post",
                description: "Structure for a blog post with metadata",
                icon: "text.bubble",
                content: """
                ---
                title: "Your Title Here"
                date: \(Date().ISO8601Format())
                tags: []
                draft: true
                ---
                
                # Your Title Here
                
                *Brief introduction paragraph...*
                
                ---
                
                ## Section 1
                
                Content here...
                
                ## Section 2
                
                More content...
                
                ## Conclusion
                
                Wrap up your post...
                
                ---
                
                *Thanks for reading!*
                """,
                fileType: .markdown,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "Project README",
                description: "README template for software projects",
                icon: "folder",
                content: """
                # Project Name
                
                Brief description of what this project does.
                
                ## Installation
                
                ```bash
                # Installation commands
                ```
                
                ## Usage
                
                ```bash
                # Usage examples
                ```
                
                ## Features
                
                - Feature 1
                - Feature 2
                - Feature 3
                
                ## Contributing
                
                1. Fork the repository
                2. Create your feature branch
                3. Commit your changes
                4. Push to the branch
                5. Open a Pull Request
                
                ## License
                
                MIT License
                """,
                fileType: .markdown,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "Journal Entry",
                description: "Daily journal with prompts",
                icon: "book",
                content: """
                # Journal - \(Date().formatted(date: .complete, time: .omitted))
                
                ## How am I feeling today?
                
                
                
                ## What happened today?
                
                
                
                ## What am I grateful for?
                
                1. 
                2. 
                3. 
                
                ## What did I learn?
                
                
                
                ## Tomorrow's intentions:
                
                - 
                - 
                - 
                """,
                fileType: .markdown,
                isBuiltIn: true
            ),
            DocumentTemplate(
                id: UUID(),
                name: "Code Snippet",
                description: "Document code with notes",
                icon: "chevron.left.forwardslash.chevron.right",
                content: """
                # Code Snippet: [Name]
                
                **Language:** 
                **Purpose:** 
                
                ---
                
                ## Code
                
                ```
                // Your code here
                ```
                
                ## Explanation
                
                
                
                ## Usage
                
                
                
                ## Notes
                
                - 
                """,
                fileType: .markdown,
                isBuiltIn: true
            )
        ]
    }
    
    // MARK: - Custom Templates
    
    private func loadCustomTemplates() {
        let files = (try? fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil)) ?? []
        
        customTemplates = files.compactMap { url -> DocumentTemplate? in
            guard url.pathExtension == "json",
                  let data = try? Data(contentsOf: url),
                  let template = try? JSONDecoder().decode(DocumentTemplate.self, from: data) else {
                return nil
            }
            return template
        }
    }
    
    func saveCustomTemplate(_ template: DocumentTemplate) {
        let url = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        
        if let data = try? JSONEncoder().encode(template) {
            try? data.write(to: url)
            loadCustomTemplates()
        }
    }
    
    func deleteCustomTemplate(_ template: DocumentTemplate) {
        let url = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        try? fileManager.removeItem(at: url)
        loadCustomTemplates()
    }
    
    func createFromTemplate(_ template: DocumentTemplate) {
        let doc = DocumentManager.shared.createNewDocument()
        DocumentManager.shared.updateContent(template.content, for: doc.id)
    }
    
    var allTemplates: [DocumentTemplate] {
        templates + customTemplates
    }
}

// MARK: - Document Template Model

struct DocumentTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var icon: String
    var content: String
    var fileType: Document.FileType
    var isBuiltIn: Bool
    
    init(id: UUID = UUID(), name: String, description: String, icon: String, content: String, fileType: Document.FileType, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.content = content
        self.fileType = fileType
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Template Picker View

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var templateManager = TemplateManager.shared
    @State private var selectedTemplate: DocumentTemplate?
    @State private var showingCreateDialog = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose a Template")
                    .font(.headline)
                
                Spacer()
                
                Button("Create Custom") {
                    showingCreateDialog = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Template Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200))
                ], spacing: 16) {
                    ForEach(templateManager.allTemplates) { template in
                        TemplateCard(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        )
                        .onTapGesture {
                            selectedTemplate = template
                        }
                        .onTapGesture(count: 2) {
                            createDocument(from: template)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                if let template = selectedTemplate {
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button("Create") {
                    if let template = selectedTemplate {
                        createDocument(from: template)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTemplate == nil)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func createDocument(from template: DocumentTemplate) {
        templateManager.createFromTemplate(template)
        dismiss()
    }
}

struct TemplateCard: View {
    let template: DocumentTemplate
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: template.icon)
                .font(.system(size: 32))
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 60, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                )
            
            Text(template.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            
            Text(template.fileType.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    TemplatePickerView()
}
