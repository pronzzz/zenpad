import SwiftUI

@main
struct ZenPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var documentManager = DocumentManager()
    @State private var showTemplates = false
    @State private var showSnippets = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(documentManager)
                .sheet(isPresented: $showTemplates) {
                    TemplatePickerView()
                }
                .sheet(isPresented: $showSnippets) {
                    SnippetManagerView()
                }
        }
        .commands {
            // File Menu
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    documentManager.createNewDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("New from Template...") {
                    showTemplates = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Open...") {
                    documentManager.openDocument()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    documentManager.saveCurrentDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                
                Button("Save As...") {
                    documentManager.saveCurrentDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                
                Divider()
                
                // Export submenu
                Menu("Export") {
                    Button("Export as PDF...") {
                        if let doc = documentManager.currentDocument {
                            ExportService.shared.exportToPDF(doc) { url in
                                if let url = url {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                            }
                        }
                    }
                    
                    Button("Export as HTML...") {
                        if let doc = documentManager.currentDocument {
                            ExportService.shared.exportToHTML(doc) { url in
                                if let url = url {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button("Create Gist...") {
                        NotificationCenter.default.post(name: .init("showGistExport"), object: nil)
                    }
                }
                .disabled(documentManager.currentDocument == nil)
                
                Divider()
                
                Button("Print...") {
                    if let doc = documentManager.currentDocument {
                        ExportService.shared.printDocument(doc)
                    }
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(documentManager.currentDocument == nil)
            }
            
            // Edit Menu - Find & Snippets
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Find...") {
                    NotificationCenter.default.post(name: .init("toggleSearch"), object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button("Find and Replace...") {
                    NotificationCenter.default.post(name: .init("toggleSearchReplace"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
                
                Divider()
                
                Button("Manage Snippets...") {
                    showSnippets = true
                }
            }
            
            // View Menu
            CommandMenu("View") {
                Button("Toggle Markdown Preview") {
                    NotificationCenter.default.post(name: .init("togglePreview"), object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Toggle Document Outline") {
                    NotificationCenter.default.post(name: .init("toggleOutline"), object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .control])
                
                Button("Toggle AI Assistant") {
                    NotificationCenter.default.post(name: .init("toggleAI"), object: nil)
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Focus Mode") {
                    NotificationCenter.default.post(name: .init("toggleFocusMode"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
                
                Divider()
                
                Button("Split Horizontally") {
                    documentManager.toggleSplitView(horizontal: true)
                }
                .keyboardShortcut("d", modifiers: [.command, .control])
                
                Button("Split Vertically") {
                    documentManager.toggleSplitView(horizontal: false)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                
                Divider()
                
                Button("Close Split") {
                    documentManager.closeSplitView()
                }
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Settings View (expanded)

struct SettingsView: View {
    var body: some View {
        TabView {
            PreferencesView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            AISettingsView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
            
            CloudSettingsView()
                .tabItem {
                    Label("Cloud", systemImage: "icloud")
                }
            
            GistSettingsView()
                .tabItem {
                    Label("GitHub", systemImage: "link")
                }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - Gist Settings

struct GistSettingsView: View {
    @State private var token = ""
    @State private var isTokenVisible = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    if isTokenVisible {
                        TextField("GitHub Token", text: $token)
                    } else {
                        SecureField("GitHub Token", text: $token)
                    }
                    
                    Button(action: { isTokenVisible.toggle() }) {
                        Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
                
                HStack {
                    Button("Save Token") {
                        GistService.shared.setToken(token)
                    }
                    .disabled(token.isEmpty)
                    
                    if GistService.shared.isAuthenticated {
                        Button("Clear Token") {
                            GistService.shared.clearToken()
                            token = ""
                        }
                    }
                }
            }
            
            Section("About") {
                Text("Create a GitHub Personal Access Token with 'gist' scope to publish Gists.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("Create Token on GitHub", destination: URL(string: "https://github.com/settings/tokens/new?scopes=gist")!)
            }
        }
        .padding()
    }
}
