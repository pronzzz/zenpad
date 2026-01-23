import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(documentManager.documents) { doc in
                    TabItemView(
                        document: doc,
                        isSelected: doc.id == documentManager.currentDocumentId,
                        onSelect: {
                            documentManager.currentDocumentId = doc.id
                        },
                        onClose: {
                            documentManager.closeDocument(doc.id)
                        }
                    )
                }
                
                // New Tab Button
                Button(action: {
                    documentManager.createNewDocument()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
                
                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TabItemView: View {
    let document: Document
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // File type icon
            Image(systemName: document.fileType == .markdown ? "doc.text" : "doc.plaintext")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Title with modified indicator
            Text(document.displayTitle)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
            
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isHovering ? Color(NSColor.separatorColor) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .opacity(isHovering || document.isModified ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    TabBarView()
        .environmentObject(DocumentManager())
}
