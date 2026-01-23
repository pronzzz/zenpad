import SwiftUI

struct AIContextMenu: View {
    let selectedText: String
    let onAction: (AIService.WritingAction) -> Void
    
    @ObservedObject private var aiService = AIService.shared
    
    var body: some View {
        if !selectedText.isEmpty && aiService.isConnected {
            Menu {
                ForEach(quickActions, id: \.self) { action in
                    Button(action: { onAction(action) }) {
                        Label(action.rawValue, systemImage: action.icon)
                    }
                }
                
                Divider()
                
                Menu("Adjust Tone") {
                    ForEach(toneActions, id: \.self) { action in
                        Button(action: { onAction(action) }) {
                            Label(action.rawValue, systemImage: action.icon)
                        }
                    }
                }
            } label: {
                Label("AI Assist", systemImage: "sparkles")
            }
        }
    }
    
    private var quickActions: [AIService.WritingAction] {
        [.rewrite, .summarize, .fixGrammar, .expand]
    }
    
    private var toneActions: [AIService.WritingAction] {
        [.makeFormal, .makeCasual, .makeConcise]
    }
}

// MARK: - AI Status Indicator for Status Bar

struct AIStatusIndicator: View {
    @ObservedObject private var aiService = AIService.shared
    
    var body: some View {
        HStack(spacing: 4) {
            if aiService.isProcessing {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(aiService.isConnected ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
            }
            
            Text(statusText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(NSColor.separatorColor).opacity(0.3))
        )
        .help(aiService.isConnected ? "AI: \(aiService.currentModel)" : "Ollama not running")
    }
    
    private var statusText: String {
        if aiService.isProcessing {
            return "Processing..."
        } else if aiService.isConnected {
            return "AI"
        } else {
            return "AI Offline"
        }
    }
}

// MARK: - AI Settings View

struct AISettingsView: View {
    @ObservedObject private var aiService = AIService.shared
    @State private var isRefreshing = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(aiService.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(aiService.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(.secondary)
                    }
                }
                
                if aiService.isConnected {
                    Picker("Model", selection: Binding(
                        get: { aiService.currentModel },
                        set: { aiService.currentModel = $0 }
                    )) {
                        ForEach(aiService.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                
                Button(action: refreshConnection) {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("Refresh Connection")
                    }
                }
                .disabled(isRefreshing)
            }
            
            Section("About") {
                Text("ZenPad uses Ollama for local AI processing. Your text never leaves your device.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
            }
        }
        .padding()
    }
    
    private func refreshConnection() {
        isRefreshing = true
        Task {
            await aiService.checkConnection()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
}

#Preview("AI Status") {
    AIStatusIndicator()
        .padding()
}

#Preview("AI Settings") {
    AISettingsView()
        .frame(width: 400, height: 300)
}
