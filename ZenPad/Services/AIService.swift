import Foundation
import Combine

/// Local writing assistant backed by Ollama. Text never leaves the Mac.
final class AIService: ObservableObject {
    static let shared = AIService()

    enum Action: String, CaseIterable, Identifiable {
        case improve, grammar, shorter, longer, summarize, continueWriting, formal, casual, titles
        var id: String { rawValue }
        var label: String {
            switch self {
            case .improve: return "Improve"
            case .grammar: return "Fix Grammar"
            case .shorter: return "Shorten"
            case .longer: return "Expand"
            case .summarize: return "Summarize"
            case .continueWriting: return "Continue"
            case .formal: return "More Formal"
            case .casual: return "More Casual"
            case .titles: return "Suggest Titles"
            }
        }
        var symbol: String {
            switch self {
            case .improve: return "wand.and.stars"
            case .grammar: return "checkmark.seal"
            case .shorter: return "arrow.down.right.and.arrow.up.left"
            case .longer: return "arrow.up.left.and.arrow.down.right"
            case .summarize: return "text.redaction"
            case .continueWriting: return "text.append"
            case .formal: return "briefcase"
            case .casual: return "cup.and.saucer"
            case .titles: return "textformat"
            }
        }
        var instruction: String {
            switch self {
            case .improve: return "Rewrite the text to improve clarity and flow while keeping its meaning, voice and Markdown formatting."
            case .grammar: return "Fix spelling, grammar and punctuation. Change nothing else. Keep the Markdown formatting."
            case .shorter: return "Make the text more concise without losing meaning. Keep the Markdown formatting."
            case .longer: return "Expand the text with more detail and examples in the same voice. Keep the Markdown formatting."
            case .summarize: return "Summarize the text as a few short Markdown bullet points."
            case .continueWriting: return "Continue writing from where the text ends, in the same voice and style. Return only the new text."
            case .formal: return "Rewrite the text in a formal, professional tone. Keep the Markdown formatting."
            case .casual: return "Rewrite the text in a warm, casual tone. Keep the Markdown formatting."
            case .titles: return "Suggest five short, compelling titles for the text, as a Markdown list."
            }
        }
        /// Whether the result should replace the source (vs. be inserted after it).
        var replaces: Bool { ![.continueWriting, .summarize, .titles].contains(self) }
    }

    @Published private(set) var isConnected = false
    @Published private(set) var models: [String] = []
    @Published private(set) var output = ""
    @Published private(set) var isRunning = false
    @Published private(set) var lastAction: Action?
    @Published var errorMessage: String?

    private var task: Task<Void, Never>?
    private var baseURL: URL { URL(string: Prefs.shared.ollamaURL) ?? URL(string: "http://localhost:11434")! }

    func refresh() async {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 3
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct Tags: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
            let tags = try JSONDecoder().decode(Tags.self, from: data)
            models = tags.models.map(\.name).sorted()
            isConnected = true
            if !models.isEmpty, !models.contains(Prefs.shared.ollamaModel),
               let match = models.first(where: { $0.hasPrefix(Prefs.shared.ollamaModel) }) ?? models.first {
                Prefs.shared.ollamaModel = match
            }
        } catch {
            isConnected = false
            models = []
        }
    }

    func run(_ action: Action?, text: String, customPrompt: String? = nil) {
        cancel()
        output = ""
        errorMessage = nil
        lastAction = action
        isRunning = true
        let instruction = customPrompt.map { "Follow this instruction about the text: \($0)" } ?? action?.instruction ?? ""
        let system = "You are a careful writing assistant inside a Markdown editor. \(instruction) Reply with the result only — no preamble, no explanations, no code fences around the whole answer."
        let body: [String: Any] = ["model": Prefs.shared.ollamaModel, "system": system, "prompt": text, "stream": true]
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        task = Task { [weak self] in
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw NSError(domain: "Ollama", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama returned HTTP \(http.statusCode). Is the model “\(Prefs.shared.ollamaModel)” installed?"])
                }
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard let data = line.data(using: .utf8),
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    if let error = json["error"] as? String { throw NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
                    if let piece = json["response"] as? String { self?.output += piece }
                    if json["done"] as? Bool == true { break }
                }
                self?.isConnected = true
            } catch is CancellationError {
            } catch {
                if (error as NSError).code == NSURLErrorCancelled { return }
                self?.errorMessage = (error as NSError).domain == NSURLErrorDomain
                    ? "Couldn't reach Ollama at \(Prefs.shared.ollamaURL). Is it running?"
                    : error.localizedDescription
                if (error as NSError).domain == NSURLErrorDomain { self?.isConnected = false }
            }
            self?.isRunning = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    func clear() {
        cancel()
        output = ""
        errorMessage = nil
        lastAction = nil
    }
}
