import Foundation

// MARK: - AI Service for Local LLM Integration

class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isConnected = false
    @Published var isProcessing = false
    @Published var currentModel = "llama3.2"
    @Published var availableModels: [String] = []
    
    private let baseURL: URL
    private let session: URLSession
    
    enum AIError: Error, LocalizedError {
        case notConnected
        case invalidResponse
        case processingFailed(String)
        case modelNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Ollama is not running. Please start Ollama first."
            case .invalidResponse:
                return "Invalid response from AI service."
            case .processingFailed(let message):
                return "AI processing failed: \(message)"
            case .modelNotAvailable:
                return "The selected model is not available."
            }
        }
    }
    
    enum WritingAction: String, CaseIterable {
        case rewrite = "Rewrite"
        case summarize = "Summarize"
        case fixGrammar = "Fix Grammar"
        case makeFormal = "Make Formal"
        case makeCasual = "Make Casual"
        case makeConcise = "Make Concise"
        case expand = "Expand"
        case generateTitle = "Generate Title"
        
        var systemPrompt: String {
            switch self {
            case .rewrite:
                return "You are a writing assistant. Rewrite the following text to improve clarity and flow while preserving the original meaning. Return only the rewritten text, no explanations."
            case .summarize:
                return "You are a writing assistant. Summarize the following text concisely, capturing the key points. Return only the summary, no explanations."
            case .fixGrammar:
                return "You are a writing assistant. Fix any grammar, spelling, and punctuation errors in the following text. Return only the corrected text, no explanations."
            case .makeFormal:
                return "You are a writing assistant. Rewrite the following text in a formal, professional tone. Return only the rewritten text, no explanations."
            case .makeCasual:
                return "You are a writing assistant. Rewrite the following text in a casual, conversational tone. Return only the rewritten text, no explanations."
            case .makeConcise:
                return "You are a writing assistant. Make the following text more concise by removing unnecessary words while preserving meaning. Return only the concise text, no explanations."
            case .expand:
                return "You are a writing assistant. Expand the following text with more detail and explanation while maintaining the original style. Return only the expanded text, no explanations."
            case .generateTitle:
                return "You are a writing assistant. Generate a clear, engaging title for the following text. Return only the title, no explanations or quotation marks."
            }
        }
        
        var icon: String {
            switch self {
            case .rewrite: return "arrow.triangle.2.circlepath"
            case .summarize: return "text.justify.left"
            case .fixGrammar: return "textformat.abc"
            case .makeFormal: return "briefcase"
            case .makeCasual: return "face.smiling"
            case .makeConcise: return "scissors"
            case .expand: return "arrow.up.left.and.arrow.down.right"
            case .generateTitle: return "textformat.size"
            }
        }
    }
    
    private init() {
        self.baseURL = URL(string: "http://localhost:11434")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        // Check connection on init
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Connection Management
    
    @MainActor
    func checkConnection() async {
        let url = baseURL.appendingPathComponent("api/tags")
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isConnected = false
                return
            }
            
            // Parse available models
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                availableModels = models.compactMap { $0["name"] as? String }
                
                // Set default model if available
                if !availableModels.isEmpty && !availableModels.contains(currentModel) {
                    currentModel = availableModels.first ?? "llama3.2"
                }
            }
            
            isConnected = true
        } catch {
            isConnected = false
            print("Ollama connection failed: \(error)")
        }
    }
    
    // MARK: - Text Processing
    
    func processText(_ text: String, action: WritingAction) async throws -> String {
        guard isConnected else {
            throw AIError.notConnected
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let url = baseURL.appendingPathComponent("api/generate")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": currentModel,
            "prompt": text,
            "system": action.systemPrompt,
            "stream": false,
            "options": [
                "temperature": 0.7,
                "top_p": 0.9
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["response"] as? String else {
            throw AIError.invalidResponse
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Convenience Methods
    
    func rewrite(_ text: String) async throws -> String {
        try await processText(text, action: .rewrite)
    }
    
    func summarize(_ text: String) async throws -> String {
        try await processText(text, action: .summarize)
    }
    
    func fixGrammar(_ text: String) async throws -> String {
        try await processText(text, action: .fixGrammar)
    }
    
    func adjustTone(_ text: String, to tone: WritingAction) async throws -> String {
        guard [.makeFormal, .makeCasual, .makeConcise].contains(tone) else {
            throw AIError.processingFailed("Invalid tone action")
        }
        return try await processText(text, action: tone)
    }
    
    func generateTitle(for text: String) async throws -> String {
        try await processText(text, action: .generateTitle)
    }
    
    func generateSummary(for text: String) async throws -> String {
        try await processText(text, action: .summarize)
    }
}
