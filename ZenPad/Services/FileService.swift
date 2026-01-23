import Foundation
import AppKit

class FileService {
    static let shared = FileService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Open Operations
    
    func showOpenPanel() -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.message = "Select files to open"
        
        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }
    
    func readFile(at url: URL) throws -> (content: String, encoding: String.Encoding) {
        // Try to detect encoding
        var usedEncoding: String.Encoding = .utf8
        
        // First try UTF-8
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            return (content, .utf8)
        }
        
        // Try to detect encoding from BOM
        let data = try Data(contentsOf: url)
        
        if data.starts(with: [0xFF, 0xFE]) {
            usedEncoding = .utf16LittleEndian
        } else if data.starts(with: [0xFE, 0xFF]) {
            usedEncoding = .utf16BigEndian
        } else if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            usedEncoding = .utf8
        }
        
        guard let content = String(data: data, encoding: usedEncoding) else {
            throw FileError.encodingError
        }
        
        return (content, usedEncoding)
    }
    
    // MARK: - Save Operations
    
    func showSavePanel(suggestedName: String, fileType: Document.FileType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.nameFieldStringValue = "\(suggestedName).\(fileType.rawValue)"
        panel.message = "Save your document"
        
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
    
    func writeFile(content: String, to url: URL, encoding: String.Encoding = .utf8) throws {
        try content.write(to: url, atomically: true, encoding: encoding)
    }
    
    // MARK: - File Info
    
    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }
    
    func fileModificationDate(at url: URL) -> Date? {
        try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }
    
    func fileSize(at url: URL) -> Int64? {
        try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64
    }
    
    // MARK: - Recent Files
    
    private var recentFilesKey = "recentFiles"
    
    var recentFiles: [URL] {
        get {
            guard let bookmarks = UserDefaults.standard.array(forKey: recentFilesKey) as? [Data] else {
                return []
            }
            
            return bookmarks.compactMap { bookmark in
                var isStale = false
                return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            }
        }
        set {
            let bookmarks = newValue.prefix(10).compactMap { url -> Data? in
                try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            UserDefaults.standard.set(bookmarks, forKey: recentFilesKey)
        }
    }
    
    func addToRecentFiles(_ url: URL) {
        var recent = recentFiles
        recent.removeAll { $0 == url }
        recent.insert(url, at: 0)
        recentFiles = Array(recent.prefix(10))
    }
    
    func clearRecentFiles() {
        recentFiles = []
    }
}

// MARK: - Errors

enum FileError: Error, LocalizedError {
    case encodingError
    case permissionDenied
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingError:
            return "Unable to determine file encoding"
        case .permissionDenied:
            return "Permission denied to access this file"
        case .fileNotFound:
            return "File not found"
        }
    }
}
