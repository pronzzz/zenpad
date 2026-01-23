import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var replaceText: String
    @Binding var isVisible: Bool
    @Binding var showReplace: Bool
    
    let matchCount: Int
    let currentMatch: Int
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void
    
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search row
            HStack(spacing: 8) {
                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField("Find...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isSearchFocused)
                        .onSubmit { onFindNext() }
                    
                    if !searchText.isEmpty {
                        Text("\(currentMatch)/\(matchCount)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                
                // Navigation buttons
                HStack(spacing: 4) {
                    Button(action: onFindPrevious) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                    
                    Button(action: onFindNext) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .disabled(matchCount == 0)
                }
                .padding(.horizontal, 8)
                
                // Replace toggle
                Button(action: { withAnimation { showReplace.toggle() } }) {
                    Image(systemName: showReplace ? "arrow.turn.down.left" : "arrow.2.squarepath")
                        .font(.system(size: 12))
                        .foregroundColor(showReplace ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(showReplace ? "Hide Replace" : "Show Replace")
                
                Spacer()
                
                // Close button
                Button(action: { isVisible = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            
            // Replace row
            if showReplace {
                HStack(spacing: 8) {
                    // Replace field
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        TextField("Replace with...", text: $replaceText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .onSubmit { onReplace() }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    
                    // Replace buttons
                    Button("Replace") { onReplace() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(matchCount == 0)
                    
                    Button("Replace All") { onReplaceAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(matchCount == 0)
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            isSearchFocused = true
        }
    }
}

#Preview {
    VStack {
        SearchBarView(
            searchText: .constant("test"),
            replaceText: .constant(""),
            isVisible: .constant(true),
            showReplace: .constant(false),
            matchCount: 5,
            currentMatch: 2,
            onFindNext: {},
            onFindPrevious: {},
            onReplace: {},
            onReplaceAll: {}
        )
        
        Spacer()
    }
}
