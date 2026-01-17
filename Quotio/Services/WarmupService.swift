//
//  WarmupService.swift
//  Quotio
//

import Foundation

actor WarmupService {
    private let antigravityBaseURLs = [
        "https://daily-cloudcode-pa.googleapis.com",
        "https://daily-cloudcode-pa.sandbox.googleapis.com",
        "https://cloudcode-pa.googleapis.com"
    ]
    
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    func warmup(authId: String, model: String) async throws {
        let tokenResponse = try await QuotioAPIClient.shared.getAuthToken(id: authId)
        let accessToken = tokenResponse.access_token
        
        let upstreamModel = mapAntigravityModelAlias(model)
        let payload = AntigravityWarmupRequest(
            project: "warmup-" + String(UUID().uuidString.prefix(5)).lowercased(),
            requestId: "agent-" + UUID().uuidString.lowercased(),
            userAgent: "antigravity",
            model: upstreamModel,
            request: AntigravityWarmupRequestBody(
                sessionId: "-" + String(UUID().uuidString.prefix(12)),
                contents: [
                    AntigravityWarmupContent(
                        role: "user",
                        parts: [AntigravityWarmupPart(text: ".")]
                    )
                ],
                generationConfig: AntigravityWarmupGenerationConfig(maxOutputTokens: 1)
            )
        )
        
        guard let bodyData = try? JSONEncoder().encode(payload) else {
            throw WarmupError.encodingFailed
        }
        
        var lastError: WarmupError?
        for baseURL in antigravityBaseURLs {
            guard let url = URL(string: baseURL + "/v1internal:generateContent") else {
                lastError = WarmupError.invalidURL
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("antigravity/1.104.0", forHTTPHeaderField: "User-Agent")
            request.httpBody = bodyData
            
            do {
                let (_, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = WarmupError.invalidResponse
                    continue
                }
                
                if 200...299 ~= httpResponse.statusCode {
                    return
                }
                lastError = WarmupError.httpError(httpResponse.statusCode, nil)
            } catch {
                lastError = WarmupError.httpError(0, error.localizedDescription)
                continue
            }
        }
        
        if let lastError {
            throw lastError
        }
        throw WarmupError.invalidResponse
    }
    
    private func mapAntigravityModelAlias(_ model: String) -> String {
        switch model.lowercased() {
        case "gemini-3-pro-preview":
            return "gemini-3-pro-high"
        case "gemini-3-flash-preview":
            return "gemini-3-flash"
        case "gemini-2.5-flash-preview":
            return "gemini-2.5-flash"
        case "gemini-2.5-flash-lite-preview":
            return "gemini-2.5-flash-lite"
        case "gemini-2.5-pro-preview":
            return "gemini-2.5-pro"
        case "gemini-claude-sonnet-4-5":
            return "claude-sonnet-4-5"
        case "gemini-claude-sonnet-4-5-thinking":
            return "claude-sonnet-4-5-thinking"
        case "gemini-claude-opus-4-5-thinking":
            return "claude-opus-4-5-thinking"
        case "gemini-2.5-computer-use-preview-10-2025":
            return "rev19-uic3-1p"
        case "gemini-3-pro-image-preview":
            return "gemini-3-pro-image"
        default:
            return model
        }
    }
    
    func fetchModels(authId: String) async throws -> [WarmupModelInfo] {
        let result = try await QuotioAPIClient.shared.getAuthModels(id: authId)
        return result.models.map { model in
            WarmupModelInfo(
                id: model.id,
                ownedBy: model.owned_by,
                provider: model.provider
            )
        }
    }
}

nonisolated struct AntigravityWarmupRequest: Codable, Sendable {
    let project: String
    let requestId: String
    let userAgent: String
    let model: String
    let request: AntigravityWarmupRequestBody
    
    enum CodingKeys: String, CodingKey {
        case project, model, request
        case requestId = "requestId"
        case userAgent = "userAgent"
    }
}

nonisolated struct AntigravityWarmupRequestBody: Codable, Sendable {
    let sessionId: String
    let contents: [AntigravityWarmupContent]
    let generationConfig: AntigravityWarmupGenerationConfig
    
    enum CodingKeys: String, CodingKey {
        case contents, generationConfig
        case sessionId = "sessionId"
    }
}

nonisolated struct AntigravityWarmupContent: Codable, Sendable {
    let role: String
    let parts: [AntigravityWarmupPart]
}

nonisolated struct AntigravityWarmupPart: Codable, Sendable {
    let text: String
}

nonisolated struct AntigravityWarmupGenerationConfig: Codable, Sendable {
    let maxOutputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case maxOutputTokens = "maxOutputTokens"
    }
}

nonisolated struct WarmupModelInfo: Codable, Sendable {
    let id: String
    let ownedBy: String?
    let provider: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
        case provider
    }
}

nonisolated enum WarmupError: Error {
    case invalidURL
    case invalidResponse
    case encodingFailed
    case httpError(Int, String?)
}

extension WarmupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid warmup URL"
        case .invalidResponse:
            return "Invalid warmup response"
        case .encodingFailed:
            return "Failed to encode warmup payload"
        case .httpError(let status, let body):
            let snippet = body?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(240)
            if let snippet, !snippet.isEmpty {
                return "Warmup HTTP \(status): \(snippet)"
            }
            return "Warmup HTTP \(status)"
        }
    }
}
