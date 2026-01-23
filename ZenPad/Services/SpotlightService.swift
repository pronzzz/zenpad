import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

class SpotlightService {
    static let shared = SpotlightService()
    
    private let searchableIndex = CSSearchableIndex.default()
    private let domainIdentifier = "com.zenpad.documents"
    
    private init() {}
    
    func indexDocument(_ document: Document) {
        guard let filePath = document.filePath else { return }
        
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = document.title
        attributeSet.contentDescription = document.content.prefix(500).description
        attributeSet.textContent = document.content
        attributeSet.contentModificationDate = document.modifiedAt
        attributeSet.contentCreationDate = document.createdAt
        attributeSet.path = filePath.path
        
        // Set content type
        if document.fileType == .markdown {
            attributeSet.contentType = "net.daringfireball.markdown"
        } else {
            attributeSet.contentType = "public.plain-text"
        }
        
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: document.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
        
        // Set expiration to never
        searchableItem.expirationDate = .distantFuture
        
        searchableIndex.indexSearchableItems([searchableItem]) { error in
            if let error = error {
                print("Spotlight indexing failed: \(error)")
            } else {
                print("Spotlight indexed: \(document.title)")
            }
        }
    }
    
    func removeDocument(_ document: Document) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [document.id.uuidString]) { error in
            if let error = error {
                print("Spotlight removal failed: \(error)")
            }
        }
    }
    
    func removeAllDocuments() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                print("Spotlight removal failed: \(error)")
            }
        }
    }
    
    func reindexAllDocuments() {
        let documents = DocumentManager.shared.documents.filter { $0.filePath != nil }
        
        for document in documents {
            indexDocument(document)
        }
    }
}
