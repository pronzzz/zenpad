import SwiftUI

struct ContentView: View {
    @EnvironmentObject var documentManager: DocumentManager
    @StateObject private var preferences = Preferences.shared
    @StateObject private var aiService = AIService.shared
    @State private var editorFont: NSFont = Preferences.shared.editorFont
    
    // Phase 2: New state variables
    @State private var showMarkdownPreview = false
    @State private var showDocumentOutline = false
    @State private var showFocusMode = false
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var showReplace = false
    @State private var searchMatches: [Range<String.Index>] = []
    @State private var currentMatchIndex = 0
    
    // Phase 3: AI state variables
    @State private var showAIPanel = false
    @State private var selectedText = ""
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Tab Bar
                TabBarView()
                
                Divider()
                
                // Search Bar (Phase 2)
                if showSearchBar {
                    SearchBarView(
                        searchText: $searchText,
                        replaceText: $replaceText,
                        isVisible: $showSearchBar,
                        showReplace: $showReplace,
                        matchCount: searchMatches.count,
                        currentMatch: searchMatches.isEmpty ? 0 : currentMatchIndex + 1,
                        onFindNext: findNext,
                        onFindPrevious: findPrevious,
                        onReplace: replaceCurrent,
                        onReplaceAll: replaceAll
                    )
                    Divider()
                }
                
                // Editor Area with optional sidebars
                HStack(spacing: 0) {
                    // Document Outline (Phase 2)
                    if showDocumentOutline {
                        DocumentOutlineView(
                            content: documentManager.currentDocument?.content ?? "",
                            onSelectHeading: scrollToLine
                        )
                        Divider()
                    }
                    
                    // Main Editor
                    editorArea
                    
                    // Markdown Preview (Phase 2)
                    if showMarkdownPreview && documentManager.currentDocument?.fileType == .markdown {
                        Divider()
                        MarkdownPreviewView(
                            markdown: documentManager.currentDocument?.content ?? "",
                            isDarkMode: .constant(preferences.isDarkMode)
                        )
                        .frame(minWidth: 300)
                    }
                }
                
                Divider()
                
                // Status Bar
                StatusBarView()
            }
            .background(preferences.isDarkMode ? Color(NSColor.windowBackgroundColor) : Color(NSColor.textBackgroundColor))
            
            // Focus Mode Overlay (Phase 2)
            if showFocusMode, let currentDoc = documentManager.currentDocument {
                FocusModeView(
                    text: Binding(
                        get: { currentDoc.content },
                        set: { documentManager.updateContent($0, for: currentDoc.id) }
                    ),
                    isActive: $showFocusMode
                )
                .transition(.opacity)
            }
            
            // AI Assistant Panel (Phase 3)
            if showAIPanel {
                HStack {
                    Spacer()
                    AIAssistantPanel(
                        selectedText: $selectedText,
                        isVisible: $showAIPanel,
                        onApply: { newText in
                            applyAIResult(newText)
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
                .padding(.top, 50)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            editorFont = preferences.editorFont
        }
        .onChange(of: preferences.fontFamily) { _ in
            editorFont = preferences.editorFont
        }
        .onChange(of: preferences.fontSize) { _ in
            editorFont = preferences.editorFont
        }
        .onChange(of: searchText) { _ in
            updateSearchMatches()
        }
        // Keyboard shortcuts for Phase 2 features
        .background(
            KeyboardShortcuts(
                onFind: { showSearchBar.toggle() },
                onFocusMode: { withAnimation { showFocusMode.toggle() } },
                onTogglePreview: { showMarkdownPreview.toggle() },
                onToggleOutline: { showDocumentOutline.toggle() }
            )
        )
        .toolbar {
            ToolbarItemGroup {
                // Outline toggle
                Button(action: { showDocumentOutline.toggle() }) {
                    Image(systemName: "list.bullet.indent")
                }
                .help("Toggle Document Outline")
                
                // Preview toggle (only for Markdown)
                if documentManager.currentDocument?.fileType == .markdown {
                    Button(action: { showMarkdownPreview.toggle() }) {
                        Image(systemName: showMarkdownPreview ? "eye.fill" : "eye")
                    }
                    .help("Toggle Markdown Preview")
                }
                
                // Focus mode
                Button(action: { withAnimation { showFocusMode.toggle() } }) {
                    Image(systemName: "text.aligncenter")
                }
                .help("Focus Mode")
                
                Divider()
                
                // AI Assistant (Phase 3)
                Button(action: { withAnimation { showAIPanel.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        if aiService.isProcessing {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .help(aiService.isConnected ? "AI Assistant (\(aiService.currentModel))" : "AI Assistant (Offline)")
            }
        }
    }
    
    // MARK: - Editor Views
    
    @ViewBuilder
    private var editorArea: some View {
        switch documentManager.splitMode {
        case .none:
            singleEditor
        case .horizontal:
            HSplitView {
                singleEditor
                if documentManager.secondaryDocumentId != nil {
                    secondaryEditor
                }
            }
        case .vertical:
            VSplitView {
                singleEditor
                if documentManager.secondaryDocumentId != nil {
                    secondaryEditor
                }
            }
        }
    }
    
    @ViewBuilder
    private var singleEditor: some View {
        if let currentDoc = documentManager.currentDocument {
            EditorView(
                text: Binding(
                    get: { currentDoc.content },
                    set: { documentManager.updateContent($0, for: currentDoc.id) }
                ),
                font: editorFont,
                lineHeight: preferences.lineHeight,
                textColor: preferences.isDarkMode ? .white : .black,
                backgroundColor: preferences.isDarkMode ? NSColor(white: 0.1, alpha: 1) : .white
            )
        } else {
            Text("No document open")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder
    private var secondaryEditor: some View {
        if let secondaryId = documentManager.secondaryDocumentId,
           let doc = documentManager.documents.first(where: { $0.id == secondaryId }) {
            EditorView(
                text: Binding(
                    get: { doc.content },
                    set: { documentManager.updateContent($0, for: doc.id) }
                ),
                font: editorFont,
                lineHeight: preferences.lineHeight,
                textColor: preferences.isDarkMode ? .white : .black,
                backgroundColor: preferences.isDarkMode ? NSColor(white: 0.1, alpha: 1) : .white
            )
        }
    }
    
    // MARK: - Search Functions
    
    private func updateSearchMatches() {
        guard !searchText.isEmpty, let content = documentManager.currentDocument?.content else {
            searchMatches = []
            return
        }
        
        searchMatches = []
        var searchRange = content.startIndex..<content.endIndex
        
        while let range = content.range(of: searchText, options: .caseInsensitive, range: searchRange) {
            searchMatches.append(range)
            searchRange = range.upperBound..<content.endIndex
        }
        
        currentMatchIndex = searchMatches.isEmpty ? 0 : min(currentMatchIndex, searchMatches.count - 1)
    }
    
    private func findNext() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        // TODO: Scroll to match in editor
    }
    
    private func findPrevious() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = currentMatchIndex == 0 ? searchMatches.count - 1 : currentMatchIndex - 1
        // TODO: Scroll to match in editor
    }
    
    private func replaceCurrent() {
        guard !searchMatches.isEmpty, let docId = documentManager.currentDocumentId else { return }
        guard var content = documentManager.currentDocument?.content else { return }
        
        let range = searchMatches[currentMatchIndex]
        content.replaceSubrange(range, with: replaceText)
        documentManager.updateContent(content, for: docId)
        updateSearchMatches()
    }
    
    private func replaceAll() {
        guard !searchText.isEmpty, let docId = documentManager.currentDocumentId else { return }
        guard let content = documentManager.currentDocument?.content else { return }
        
        let newContent = content.replacingOccurrences(of: searchText, with: replaceText, options: .caseInsensitive)
        documentManager.updateContent(newContent, for: docId)
        updateSearchMatches()
    }
    
    private func scrollToLine(_ lineNumber: Int) {
        // TODO: Implement scroll to line in EditorView
        print("Scroll to line: \(lineNumber)")
    }
    
    // MARK: - AI Functions (Phase 3)
    
    private func applyAIResult(_ newText: String) {
        guard let docId = documentManager.currentDocumentId else { return }
        guard var content = documentManager.currentDocument?.content else { return }
        
        // If there's selected text, replace it; otherwise append
        if !selectedText.isEmpty, let range = content.range(of: selectedText) {
            content.replaceSubrange(range, with: newText)
        } else {
            content.append("\n\n" + newText)
        }
        
        documentManager.updateContent(content, for: docId)
        selectedText = ""
    }
}

// MARK: - Keyboard Shortcuts Helper

struct KeyboardShortcuts: View {
    let onFind: () -> Void
    let onFocusMode: () -> Void
    let onTogglePreview: () -> Void
    let onToggleOutline: () -> Void
    
    var body: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: .init("toggleSearch"))) { _ in
                onFind()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("toggleSearchReplace"))) { _ in
                onFind()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("toggleFocusMode"))) { _ in
                onFocusMode()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("togglePreview"))) { _ in
                onTogglePreview()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("toggleOutline"))) { _ in
                onToggleOutline()
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(DocumentManager())
}

