import Foundation

class AutoSaveService {
    static let shared = AutoSaveService()
    
    private var timer: Timer?
    private let preferences = Preferences.shared
    private let fileManager = FileManager.default
    
    private var versionsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let zenPadDir = appSupport.appendingPathComponent("ZenPad/versions", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: zenPadDir.path) {
            try? fileManager.createDirectory(at: zenPadDir, withIntermediateDirectories: true)
        }
        
        return zenPadDir
    }
    
    private init() {}
    
    func startAutoSave() {
        guard preferences.autoSaveEnabled else { return }
        
        stopAutoSave()
        
        timer = Timer.scheduledTimer(withTimeInterval: preferences.autoSaveInterval, repeats: true) { [weak self] _ in
            self?.performAutoSave()
        }
    }
    
    func stopAutoSave() {
        timer?.invalidate()
        timer = nil
    }
    
    private func performAutoSave() {
        guard preferences.autoSaveEnabled else { return }
        
        let documents = DocumentManager.shared.documents.filter { $0.isModified && $0.filePath != nil }
        
        for document in documents {
            guard let filePath = document.filePath else { continue }
            
            do {
                // Create version before saving
                createVersion(for: document)
                
                // Save to file
                try document.content.write(to: filePath, atomically: true, encoding: document.encoding)
                
                // Update document state
                DocumentManager.shared.updateContent(document.content, for: document.id)
                
                print("Auto-saved: \(document.title)")
            } catch {
                print("Auto-save failed for \(document.title): \(error)")
            }
        }
    }
    
    func createVersion(for document: Document) {
        let version = DocumentVersion(
            documentId: document.id,
            content: document.content,
            changeDescription: "Auto-save"
        )
        
        saveVersion(version)
        cleanupOldVersions(for: document.id)
    }
    
    private func saveVersion(_ version: DocumentVersion) {
        let documentDir = versionsDirectory.appendingPathComponent(version.documentId.uuidString, isDirectory: true)
        
        // Create document-specific directory
        if !fileManager.fileExists(atPath: documentDir.path) {
            try? fileManager.createDirectory(at: documentDir, withIntermediateDirectories: true)
        }
        
        // Save version as JSON
        let versionFile = documentDir.appendingPathComponent("\(version.id.uuidString).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(version)
            try data.write(to: versionFile)
        } catch {
            print("Failed to save version: \(error)")
        }
    }
    
    private func cleanupOldVersions(for documentId: UUID) {
        let documentDir = versionsDirectory.appendingPathComponent(documentId.uuidString, isDirectory: true)
        
        guard fileManager.fileExists(atPath: documentDir.path) else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentDir, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "json" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return date1 ?? Date.distantPast > date2 ?? Date.distantPast
                }
            
            // Keep only maxVersions most recent
            if files.count > preferences.maxVersions {
                let filesToDelete = files.suffix(from: preferences.maxVersions)
                for file in filesToDelete {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to cleanup versions: \(error)")
        }
    }
    
    func getVersions(for documentId: UUID) -> [DocumentVersion] {
        let documentDir = versionsDirectory.appendingPathComponent(documentId.uuidString, isDirectory: true)
        
        guard fileManager.fileExists(atPath: documentDir.path) else { return [] }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            var versions: [DocumentVersion] = []
            for file in files {
                if let data = try? Data(contentsOf: file),
                   let version = try? decoder.decode(DocumentVersion.self, from: data) {
                    versions.append(version)
                }
            }
            
            return versions.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to load versions: \(error)")
            return []
        }
    }
}
