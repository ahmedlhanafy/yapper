import Foundation
import Combine

struct OllamaModel: Identifiable, Hashable {
    let name: String
    let size: Int64
    let modifiedAt: String

    var id: String { name }
}

enum OllamaError: LocalizedError {
    case notRunning
    case noModels
    case connectionFailed(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Ollama is not running. Start it and try again."
        case .noModels:
            return "No Ollama models found. Pull one with: ollama pull llama3"
        case .connectionFailed(let error):
            return "Could not connect to Ollama: \(error.localizedDescription)"
        case .invalidResponse:
            return "Got an unexpected response from Ollama."
        }
    }
}

class OllamaService: ObservableObject {
    static let shared = OllamaService()

    @Published var isRunning = false
    @Published var availableModels: [OllamaModel] = []
    @Published var isChecking = false

    var baseURL: URL {
        let urlString = AppState.shared.settings.ollamaBaseURL
        return URL(string: urlString) ?? URL(string: "http://localhost:11434")!
    }

    private init() {}

    // MARK: - Health check

    @MainActor
    func checkStatus() async {
        isChecking = true
        defer { isChecking = false }

        let healthURL = baseURL
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                isRunning = true
                await fetchModels()
            } else {
                isRunning = false
                availableModels = []
            }
        } catch {
            isRunning = false
            availableModels = []
        }
    }

    // MARK: - Model discovery

    @MainActor
    func fetchModels() async {
        let url = baseURL.appendingPathComponent("api/tags")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let models = json?["models"] as? [[String: Any]] else {
                availableModels = []
                return
            }

            availableModels = models.compactMap { entry in
                guard let name = entry["name"] as? String else { return nil }
                let size = entry["size"] as? Int64 ?? 0
                let modified = entry["modified_at"] as? String ?? ""
                return OllamaModel(name: name, size: size, modifiedAt: modified)
            }
        } catch {
            availableModels = []
        }
    }

    // MARK: - Chat completion

    func chatCompletion(model: String, messages: [[String: String]]) async throws -> String {
        let url = baseURL.appendingPathComponent("api/chat")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OllamaError.connectionFailed(error)
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let message = json?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OllamaError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
