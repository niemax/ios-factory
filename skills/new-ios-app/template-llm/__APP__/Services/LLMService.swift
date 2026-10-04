import FirebaseAuth
import Foundation

enum LLMProvider: String, Encodable, Sendable {
    case __LLM_CASES__
}

struct LLMMessage: Encodable, Sendable {
    enum Role: String, Encodable, Sendable {
        case user, assistant
    }

    let role: Role
    let content: String
}

enum LLMError: Error {
    case notConfigured
    case server(status: Int, message: String?)
}

@MainActor
protocol LLMProviding {
    func complete(_ messages: [LLMMessage], provider: LLMProvider, system: String?, model: String?) async throws -> String
}

/// Calls the app's own backend (`backend/`), never a provider directly: the API keys live in
/// Firebase secrets. Signs in anonymously when nobody is signed in, since the backend needs a uid.
@MainActor
struct LLMService: LLMProviding {
    private struct RequestBody: Encodable {
        let provider: LLMProvider
        let model: String?
        let system: String?
        let messages: [LLMMessage]
    }

    private struct Reply: Decodable {
        let text: String
    }

    private struct ErrorReply: Decodable {
        let error: String
    }

    func complete(_ messages: [LLMMessage], provider: LLMProvider, system: String? = nil, model: String? = nil) async throws -> String {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String,
              let backendURL = URL(string: base) else { throw LLMError.notConfigured }
        let token = try await idToken()

        var request = URLRequest(url: backendURL.appending(path: "llm"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(provider: provider, model: model, system: system, messages: messages))

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw LLMError.server(status: status, message: try? JSONDecoder().decode(ErrorReply.self, from: data).error)
        }
        return try JSONDecoder().decode(Reply.self, from: data).text
    }

    private func idToken() async throws -> String {
        if let user = Auth.auth().currentUser { return try await user.getIDToken() }
        return try await Auth.auth().signInAnonymously().user.getIDToken()
    }
}
