import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var documentManager: DocumentManager
    
    private var stats: TextStatistics {
        guard let doc = documentManager.currentDocument else {
            return TextStatistics(text: "")
        }
        return TextStatistics(text: doc.content)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // File type indicator
            if let doc = documentManager.currentDocument {
                Text(doc.fileType.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(NSColor.separatorColor).opacity(0.3))
                    )
            }
            
            Spacer()
            
            // Statistics
            HStack(spacing: 12) {
                StatItem(label: "Words", value: "\(stats.wordCount)")
                StatItem(label: "Chars", value: "\(stats.characterCount)")
                StatItem(label: "Reading", value: stats.readingTime)
            }
            
            // AI Status (Phase 3)
            AIStatusIndicator()
            
            // Encoding indicator
            if let doc = documentManager.currentDocument {
                Text(encodingName(for: doc.encoding))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func encodingName(for encoding: String.Encoding) -> String {
        switch encoding {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .ascii: return "ASCII"
        default: return "UTF-8"
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    StatusBarView()
        .environmentObject(DocumentManager())
}
