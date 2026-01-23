import Foundation

struct Document: Identifiable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var filePath: URL?
    var encoding: String.Encoding
    var isModified: Bool
    var createdAt: Date
    var modifiedAt: Date
    var fileType: FileType
    
    enum FileType: String, CaseIterable, Codable {
        case plainText = "txt"
        case markdown = "md"
        
        var displayName: String {
            switch self {
            case .plainText: return "Plain Text"
            case .markdown: return "Markdown"
            }
        }
        
        var utType: String {
            switch self {
            case .plainText: return "public.plain-text"
            case .markdown: return "net.daringfireball.markdown"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String = "Untitled",
        content: String = "",
        filePath: URL? = nil,
        encoding: String.Encoding = .utf8,
        isModified: Bool = false,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        fileType: FileType = .plainText
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.filePath = filePath
        self.encoding = encoding
        self.isModified = isModified
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.fileType = fileType
    }
    
    var displayTitle: String {
        if isModified {
            return "• \(title)"
        }
        return title
    }
    
    static func detectFileType(from url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        return FileType(rawValue: ext) ?? .plainText
    }
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Document Version for history
struct DocumentVersion: Identifiable, Codable {
    let id: UUID
    let documentId: UUID
    let content: String
    let timestamp: Date
    let changeDescription: String?
    
    init(
        id: UUID = UUID(),
        documentId: UUID,
        content: String,
        timestamp: Date = Date(),
        changeDescription: String? = nil
    ) {
        self.id = id
        self.documentId = documentId
        self.content = content
        self.timestamp = timestamp
        self.changeDescription = changeDescription
    }
}
