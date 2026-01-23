import SwiftUI

struct FocusModeView: View {
    @Binding var text: String
    @Binding var isActive: Bool
    @StateObject private var preferences = Preferences.shared
    
    @State private var paragraphs: [String] = []
    @State private var focusedParagraphIndex: Int = 0
    @State private var typewriterOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Exit button
                    HStack {
                        Spacer()
                        Button(action: { isActive = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Focused content area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                    Text(paragraph)
                                        .font(.custom(preferences.fontFamily, size: preferences.fontSize + 4))
                                        .foregroundColor(paragraphColor(for: index))
                                        .lineSpacing(8)
                                        .frame(maxWidth: min(geometry.size.width * 0.7, 700), alignment: .leading)
                                        .id(index)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                focusedParagraphIndex = index
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, geometry.size.height * 0.3)
                        }
                        .onChange(of: focusedParagraphIndex) { newValue in
                            withAnimation {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Navigation hints
                    HStack(spacing: 40) {
                        Button(action: previousParagraph) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(focusedParagraphIndex == 0)
                        
                        Text("\(focusedParagraphIndex + 1) / \(paragraphs.count)")
                            .font(.system(size: 12, weight: .medium))
                        
                        Button(action: nextParagraph) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(focusedParagraphIndex >= paragraphs.count - 1)
                    }
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 30)
                }
            }
            .onAppear {
                updateParagraphs()
            }
            .onChange(of: text) { _ in
                updateParagraphs()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("focusModeKeyPress"))) { notification in
                if let key = notification.object as? String {
                    handleKeyPress(key)
                }
            }
        }
    }
    
    private func paragraphColor(for index: Int) -> Color {
        if index == focusedParagraphIndex {
            return .white
        } else {
            let distance = abs(index - focusedParagraphIndex)
            let opacity = max(0.15, 0.4 - Double(distance) * 0.1)
            return .white.opacity(opacity)
        }
    }
    
    private func updateParagraphs() {
        paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if paragraphs.isEmpty {
            paragraphs = ["Start writing..."]
        }
        
        // Clamp focused index
        focusedParagraphIndex = min(focusedParagraphIndex, max(0, paragraphs.count - 1))
    }
    
    private func previousParagraph() {
        withAnimation(.easeInOut(duration: 0.3)) {
            focusedParagraphIndex = max(0, focusedParagraphIndex - 1)
        }
    }
    
    private func nextParagraph() {
        withAnimation(.easeInOut(duration: 0.3)) {
            focusedParagraphIndex = min(paragraphs.count - 1, focusedParagraphIndex + 1)
        }
    }
    
    private func handleKeyPress(_ key: String) {
        switch key {
        case "up":
            previousParagraph()
        case "down":
            nextParagraph()
        case "escape":
            isActive = false
        default:
            break
        }
    }
}

#Preview {
    FocusModeView(
        text: .constant("""
        This is the first paragraph of text. It contains multiple sentences to demonstrate the focus mode functionality.
        
        Here is the second paragraph. When you click on a paragraph, it becomes the focused one and the others dim out.
        
        The third paragraph shows how navigation works. You can use the arrow buttons or keyboard to move between paragraphs.
        
        Finally, the fourth paragraph demonstrates the smooth scrolling and centering behavior.
        """),
        isActive: .constant(true)
    )
}
