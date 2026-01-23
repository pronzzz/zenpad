import SwiftUI

struct DocumentOutlineView: View {
    let content: String
    let onSelectHeading: (Int) -> Void
    
    @State private var headings: [HeadingItem] = []
    @State private var isExpanded = true
    
    struct HeadingItem: Identifiable {
        let id = UUID()
        let level: Int
        let text: String
        let lineNumber: Int
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Outline")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            if isExpanded {
                if headings.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No headings found")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Use # for headings")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(headings) { heading in
                                HeadingRow(heading: heading, onSelect: {
                                    onSelectHeading(heading.lineNumber)
                                })
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(width: 200)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { parseHeadings() }
        .onChange(of: content) { _ in parseHeadings() }
    }
    
    private func parseHeadings() {
        var result: [HeadingItem] = []
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("#") {
                // Count heading level
                var level = 0
                for char in trimmed {
                    if char == "#" {
                        level += 1
                    } else {
                        break
                    }
                }
                
                if level > 0 && level <= 6 {
                    let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        result.append(HeadingItem(level: level, text: text, lineNumber: index + 1))
                    }
                }
            }
        }
        
        headings = result
    }
}

struct HeadingRow: View {
    let heading: DocumentOutlineView.HeadingItem
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                // Level indicator
                Circle()
                    .fill(levelColor)
                    .frame(width: 6, height: 6)
                
                Text(heading.text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.leading, CGFloat(heading.level - 1) * 12 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color(NSColor.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
    
    private var fontSize: CGFloat {
        switch heading.level {
        case 1: return 13
        case 2: return 12
        default: return 11
        }
    }
    
    private var fontWeight: Font.Weight {
        switch heading.level {
        case 1: return .semibold
        case 2: return .medium
        default: return .regular
        }
    }
    
    private var levelColor: Color {
        switch heading.level {
        case 1: return .blue
        case 2: return .purple
        case 3: return .green
        case 4: return .orange
        case 5: return .pink
        default: return .gray
        }
    }
}

#Preview {
    DocumentOutlineView(
        content: """
        # Main Title
        
        Some intro text here.
        
        ## First Section
        
        Content for first section.
        
        ### Subsection A
        
        Details about A.
        
        ### Subsection B
        
        Details about B.
        
        ## Second Section
        
        More content here.
        
        # Another Main Section
        
        Final content.
        """,
        onSelectHeading: { line in
            print("Selected heading at line \(line)")
        }
    )
}
