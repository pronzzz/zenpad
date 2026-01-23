import Foundation
import Combine

class DocumentManager: ObservableObject {
    static let shared = DocumentManager()
    
    @Published var documents: [Document] = []
    @Published var currentDocumentId: UUID?
    @Published var splitMode: SplitMode = .none
    @Published var secondaryDocumentId: UUID?
    
    enum SplitMode {
        case none
        case horizontal
        case vertical
    }
    
    var currentDocument: Document? {
        get {
            guard let id = currentDocumentId else { return nil }
            return documents.first { $0.id == id }
        }
        set {
            if let doc = newValue, let index = documents.firstIndex(where: { $0.id == doc.id }) {
                documents[index] = doc
            }
        }
    }
    
    var hasUnsavedDocuments: Bool {
        documents.contains { $0.isModified }
    }
    
    init() {
        // Create initial empty document
        createNewDocument()
    }
    
    @discardableResult
    func createNewDocument() -> Document {
        let doc = Document()
        documents.append(doc)
        currentDocumentId = doc.id
        return doc
    }
    
    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                openDocument(at: url)
            }
        }
    }
    
    func openDocument(at url: URL) {
        // Check if already open
        if let existingDoc = documents.first(where: { $0.filePath == url }) {
            currentDocumentId = existingDoc.id
            return
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let doc = Document(
                title: url.deletingPathExtension().lastPathComponent,
                content: content,
                filePath: url,
                fileType: Document.detectFileType(from: url)
            )
            documents.append(doc)
            currentDocumentId = doc.id
            
            // Index for Spotlight
            SpotlightService.shared.indexDocument(doc)
        } catch {
            print("Error opening file: \(error)")
        }
    }
    
    func saveCurrentDocument() {
        guard var doc = currentDocument else { return }
        
        if let path = doc.filePath {
            do {
                try doc.content.write(to: path, atomically: true, encoding: doc.encoding)
                doc.isModified = false
                doc.modifiedAt = Date()
                currentDocument = doc
                
                // Create version
                AutoSaveService.shared.createVersion(for: doc)
                
                // Update Spotlight index
                SpotlightService.shared.indexDocument(doc)
            } catch {
                print("Error saving file: \(error)")
            }
        } else {
            saveCurrentDocumentAs()
        }
    }
    
    func saveCurrentDocumentAs() {
        guard var doc = currentDocument else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.nameFieldStringValue = doc.title
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try doc.content.write(to: url, atomically: true, encoding: doc.encoding)
                doc.filePath = url
                doc.title = url.deletingPathExtension().lastPathComponent
                doc.fileType = Document.detectFileType(from: url)
                doc.isModified = false
                doc.modifiedAt = Date()
                currentDocument = doc
                
                // Create version
                AutoSaveService.shared.createVersion(for: doc)
                
                // Update Spotlight index
                SpotlightService.shared.indexDocument(doc)
            } catch {
                print("Error saving file: \(error)")
            }
        }
    }
    
    func saveAllDocuments() {
        for doc in documents where doc.isModified {
            currentDocumentId = doc.id
            saveCurrentDocument()
        }
    }
    
    func closeDocument(_ id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        
        let doc = documents[index]
        
        if doc.isModified {
            let alert = NSAlert()
            alert.messageText = "Save changes to \"\(doc.title)\"?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                currentDocumentId = doc.id
                saveCurrentDocument()
            case .alertThirdButtonReturn:
                return
            default:
                break
            }
        }
        
        // Remove from Spotlight
        SpotlightService.shared.removeDocument(doc)
        
        documents.remove(at: index)
        
        // Select another document
        if currentDocumentId == id {
            currentDocumentId = documents.first?.id
        }
        
        // If no documents remain, create a new one
        if documents.isEmpty {
            createNewDocument()
        }
    }
    
    func updateContent(_ content: String, for documentId: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[index].content = content
        documents[index].isModified = true
        documents[index].modifiedAt = Date()
    }
    
    func toggleSplitView(horizontal: Bool) {
        if splitMode != .none {
            closeSplitView()
        }
        splitMode = horizontal ? .horizontal : .vertical
        secondaryDocumentId = currentDocumentId
    }
    
    func closeSplitView() {
        splitMode = .none
        secondaryDocumentId = nil
    }
}

// AppKit imports for panels
import AppKit
