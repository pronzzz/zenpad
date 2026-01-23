import SwiftUI

struct AIAssistantPanel: View {
    @Binding var selectedText: String
    @Binding var isVisible: Bool
    @ObservedObject var aiService = AIService.shared
    
    @State private var result: String = ""
    @State private var error: String?
    @State private var selectedAction: AIService.WritingAction?
    @State private var showDiff = false
    
    let onApply: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            if !aiService.isConnected {
                connectionWarning
            } else if selectedText.isEmpty {
                emptyState
            } else {
                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Original text preview
                        originalTextSection
                        
                        // Action buttons
                        actionButtons
                        
                        // Result section
                        if !result.isEmpty {
                            resultSection
                        }
                        
                        // Error display
                        if let error = error {
                            errorSection(error)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
            
            Text("AI Assistant")
                .font(.system(size: 13, weight: .semibold))
            
            Spacer()
            
            // Connection indicator
            Circle()
                .fill(aiService.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Button(action: { isVisible = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Connection Warning
    
    private var connectionWarning: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            Text("Ollama Not Running")
                .font(.system(size: 14, weight: .medium))
            
            Text("Start Ollama to use AI features.\nRun 'ollama serve' in Terminal.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry Connection") {
                Task {
                    await aiService.checkConnection()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(30)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.cursor")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select text to get started")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Highlight text in the editor, then choose an AI action.")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }
    
    // MARK: - Original Text Section
    
    private var originalTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Text")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(selectedText)
                .font(.system(size: 12))
                .lineLimit(4)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AIService.WritingAction.allCases, id: \.self) { action in
                    ActionButton(
                        action: action,
                        isSelected: selectedAction == action,
                        isProcessing: aiService.isProcessing && selectedAction == action
                    ) {
                        performAction(action)
                    }
                }
            }
        }
    }
    
    // MARK: - Result Section
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showDiff.toggle() }) {
                    Image(systemName: showDiff ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(showDiff ? "Hide comparison" : "Show comparison")
            }
            
            Text(result)
                .font(.system(size: 12))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            
            HStack(spacing: 8) {
                Button("Apply") {
                    onApply(result)
                    result = ""
                    selectedAction = nil
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Discard") {
                    result = ""
                    selectedAction = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.red)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Actions
    
    private func performAction(_ action: AIService.WritingAction) {
        selectedAction = action
        error = nil
        result = ""
        
        Task {
            do {
                result = try await aiService.processText(selectedText, action: action)
            } catch let aiError as AIService.AIError {
                error = aiError.localizedDescription
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let action: AIService.WritingAction
    let isSelected: Bool
    let isProcessing: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: action.icon)
                        .font(.system(size: 11))
                }
                
                Text(action.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.purple.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.purple : Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }
}

#Preview {
    AIAssistantPanel(
        selectedText: .constant("This is some sample text that needs to be improved."),
        isVisible: .constant(true),
        onApply: { _ in }
    )
}
