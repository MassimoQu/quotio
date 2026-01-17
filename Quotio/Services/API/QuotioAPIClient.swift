//
//  QuotioAPIClient.swift
//  Quotio
//
//  HTTP client for communicating with the Quotio server via REST API.
//  Replaces DaemonIPCClient with HTTP-based communication.
//
//  Types are defined in QuotioAPITypes.swift to ensure proper Sendable conformance.
//

import Foundation

// MARK: - QuotioAPIClient

actor QuotioAPIClient {
    private let session: URLSession
    private let baseURL: String
    private let timeout: TimeInterval
    private(set) var state: APIConnectionState = .disconnected

    static let shared = QuotioAPIClient()

    init(baseURL: String = "http://localhost:18317", timeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    var isConnected: Bool {
        if case .connected = state {
            return true
        }
        return false
    }

    // MARK: - Connection Management

    func connect() async throws {
        if case .connected = state {
            return
        }

        state = .connecting

        // Try to reach the health endpoint
        do {
            let health: HealthResponse = try await get(endpoint: "/api/health")
            state = .connected
            NSLog("[QuotioAPIClient] Connected to server version: \(health.version)")
        } catch {
            state = .failed("Server not reachable")
            throw APIClientError.serverNotRunning
        }
    }

    func disconnect() {
        state = .disconnected
    }

    // MARK: - Request Methods

    private func get<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.connectionFailed("Invalid URL: \(baseURL + endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await performRequest(request)
    }

    private func post<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.connectionFailed("Invalid URL: \(baseURL + endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    private func delete<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.connectionFailed("Invalid URL: \(baseURL + endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await performRequest(request)
    }

    private func put<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.connectionFailed("Invalid URL: \(baseURL + endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    private func patch<T: Decodable, B: Encodable>(endpoint: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIClientError.connectionFailed("Invalid URL: \(baseURL + endpoint)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return try await performRequest(request)
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cannotConnectToHost || error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                throw APIClientError.serverNotRunning
            }
            throw APIClientError.connectionFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error message from response
            var errorMessage: String?
            if let responseDict = try? JSONDecoder().decode([String: String].self, from: data),
               let message = responseDict["message"] ?? responseDict["error"] {
                errorMessage = message
            }
            throw APIClientError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingError(error)
        }
    }

    // MARK: - Lifecycle Endpoints

    func ping() async throws -> HealthResponse {
        try await get(endpoint: "/api/health")
    }
    
    /// Simple health check that returns true if server is reachable
    func health() async -> Bool {
        do {
            let _: HealthResponse = try await get(endpoint: "/api/health")
            return true
        } catch {
            return false
        }
    }

    func status() async throws -> StatusResponse {
        try await get(endpoint: "/api/status")
    }

    func shutdown(graceful: Bool = true) async throws {
        let _: EmptyResponse = try await post(endpoint: "/api/proxy/stop", body: EmptyBody())
    }
    
    /// Start proxy - In HTTP mode, server IS the proxy, so this is a no-op if server is running
    func startProxy(port: Int? = nil) async throws -> ProxyStartResponse {
        try await post(endpoint: "/api/proxy/start", body: EmptyBody())
    }
    
    /// Stop proxy - Initiates graceful shutdown
    func stopProxy() async throws -> ProxyStopResponse {
        try await post(endpoint: "/api/proxy/stop", body: EmptyBody())
    }

    func proxyStatus() async throws -> ProxyStatusResponse {
        try await get(endpoint: "/api/proxy/status")
    }

    func getLatestVersion() async throws -> ServerLatestVersionResponse {
        try await get(endpoint: "/api/proxy/latest-version")
    }

    // MARK: - Auth Endpoints

    func listAuth(provider: String? = nil) async throws -> AuthListResponse {
        if let provider = provider {
            try await get(endpoint: "/api/auth?provider=\(provider)")
        } else {
            try await get(endpoint: "/api/auth")
        }
    }

    func deleteAuth(name: String) async throws -> DeleteAuthResponse {
        try await delete(endpoint: "/api/auth/\(name)")
    }

    func deleteAllAuth() async throws -> DeleteAllAuthResponse {
        try await delete(endpoint: "/api/auth")
    }

    func setAuthDisabled(id: String, disabled: Bool) async throws -> SetDisabledResponse {
        let body = DisabledBody(disabled: disabled)
        return try await put(endpoint: "/api/auth/\(id)/disabled", body: body)
    }

    func getAuthModels(id: String) async throws -> AuthModelsResponse {
        try await get(endpoint: "/api/auth/\(id)/models")
    }

    func getAuthToken(id: String) async throws -> AuthTokenResponse {
        try await get(endpoint: "/api/auth/\(id)/token")
    }

    // MARK: - OAuth Endpoints

    func startOAuth(provider: String) async throws -> OAuthStartResponse {
        return try await post(endpoint: "/api/oauth/\(provider)/start", body: EmptyBody())
    }

    func pollOAuthStatus(provider: String, state: String) async throws -> OAuthPollResponse {
        try await get(endpoint: "/api/oauth/\(provider)/poll?state=\(state)")
    }
    
    func cancelOAuth(provider: String, state: String) async throws -> OAuthCancelResponse {
        let body = CancelOAuthBody(state: state)
        return try await post(endpoint: "/api/oauth/\(provider)/cancel", body: body)
    }

    func startDeviceCode(provider: String) async throws -> DeviceCodeResponse {
        return try await post(endpoint: "/api/device-code/\(provider)/start", body: EmptyBody())
    }

    func pollDeviceCode(provider: String, deviceCode: String) async throws -> DeviceCodePollResponse {
        try await get(endpoint: "/api/device-code/\(provider)/poll?device_code=\(deviceCode)")
    }
    
    func cancelDeviceCode(provider: String, deviceCode: String) async throws -> OAuthCancelResponse {
        let body = CancelDeviceCodeBody(device_code: deviceCode)
        return try await post(endpoint: "/api/device-code/\(provider)/cancel", body: body)
    }

    func refreshToken(provider: String? = nil) async throws -> RefreshTokenResponse {
        let body = RefreshBody(provider: provider)
        return try await post(endpoint: "/api/auth/refresh", body: body)
    }

    // MARK: - Quota Endpoints

    func fetchQuotas(provider: String? = nil, forceRefresh: Bool = false) async throws -> QuotaFetchResponse {
        var endpoint = "/api/quota"
        if let provider = provider {
            endpoint += "/\(provider)"
        }
        if forceRefresh {
            endpoint += endpoint.contains("?") ? "&refresh=true" : "?refresh=true"
        }
        return try await get(endpoint: endpoint)
    }

    func listQuotas() async throws -> QuotaListResponse {
        try await get(endpoint: "/api/quota")
    }

    func refreshQuotaTokens(provider: String? = nil) async throws -> QuotaRefreshResponse {
        let endpoint = provider != nil ? "/api/quota/\(provider!)/refresh" : "/api/quota/refresh"
        return try await post(endpoint: endpoint, body: EmptyBody())
    }

    func fetchCopilotAvailableModels() async throws -> CopilotAvailableModelsResponse {
        try await get(endpoint: "/api/quota/copilot/models")
    }

    // MARK: - Agent Endpoints

    func detectAgents(forceRefresh: Bool = false) async throws -> AgentDetectResponse {
        let endpoint = forceRefresh ? "/api/agents?refresh=true" : "/api/agents"
        return try await get(endpoint: endpoint)
    }

    func configureAgent(agent: String, mode: String, config: AgentConfigBody? = nil) async throws -> AgentConfigureResponse {
        let body = ConfigureAgentBody(mode: mode, config: config)
        return try await post(endpoint: "/api/agents/\(agent)/configure", body: body)
    }

    // MARK: - Config Endpoints

    func getAllConfig() async throws -> ServerConfigResponse {
        try await get(endpoint: "/api/config")
    }

    func getProxyUrl() async throws -> APIProxyURLResponse {
        try await get(endpoint: "/api/config/proxy-url")
    }

    func setProxyUrl(_ url: String) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: url)
        return try await put(endpoint: "/api/config/proxy-url", body: body)
    }

    func deleteProxyUrl() async throws -> ConfigSuccessResponse {
        try await delete(endpoint: "/api/config/proxy-url")
    }

    func getRoutingStrategy() async throws -> APIRoutingStrategyResponse {
        try await get(endpoint: "/api/config/routing/strategy")
    }

    func setRoutingStrategy(_ strategy: String) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: strategy)
        return try await put(endpoint: "/api/config/routing/strategy", body: body)
    }

    func getDebugMode() async throws -> DebugModeResponse {
        try await get(endpoint: "/api/config/debug")
    }

    func setDebugMode(_ enabled: Bool) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: enabled)
        return try await put(endpoint: "/api/config/debug", body: body)
    }

    func getRequestRetry() async throws -> APIRequestRetryResponse {
        try await get(endpoint: "/api/config/request-retry")
    }

    func setRequestRetry(_ count: Int) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: count)
        return try await put(endpoint: "/api/config/request-retry", body: body)
    }

    func getMaxRetryInterval() async throws -> APIMaxRetryIntervalResponse {
        try await get(endpoint: "/api/config/max-retry-interval")
    }

    func setMaxRetryInterval(_ seconds: Int) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: seconds)
        return try await put(endpoint: "/api/config/max-retry-interval", body: body)
    }

    func getLoggingToFile() async throws -> APILoggingToFileResponse {
        try await get(endpoint: "/api/config/logging-to-file")
    }

    func setLoggingToFile(_ enabled: Bool) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: enabled)
        return try await put(endpoint: "/api/config/logging-to-file", body: body)
    }

    func setQuotaExceededSwitchProject(_ enabled: Bool) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: enabled)
        return try await patch(endpoint: "/api/config/quota-exceeded/switch-project", body: body)
    }

    func setQuotaExceededSwitchPreviewModel(_ enabled: Bool) async throws -> ConfigSuccessResponse {
        let body = ConfigValueBody(value: enabled)
        return try await patch(endpoint: "/api/config/quota-exceeded/switch-preview-model", body: body)
    }

    func getLocalManagementKey() async throws -> ManagementKeyResponse {
        try await get(endpoint: "/api/config/management-key")
    }

    func setLocalManagementKey(_ key: String) async throws -> SetManagementKeyResponse {
        let body = ManagementKeyBody(key: key)
        return try await post(endpoint: "/api/config/management-key", body: body)
    }

    // MARK: - Fallback Endpoints

    func getFallbackConfig() async throws -> FallbackConfigResponse {
        try await get(endpoint: "/api/fallback")
    }

    func setFallbackEnabled(_ enabled: Bool) async throws -> FallbackEnabledResponse {
        let body = FallbackEnabledBody(enabled: enabled)
        return try await post(endpoint: "/api/fallback/enabled", body: body)
    }

    func listFallbackModels() async throws -> FallbackModelsResponse {
        try await get(endpoint: "/api/fallback/models")
    }

    func getFallbackModel(name: String) async throws -> FallbackModelResponse {
        try await get(endpoint: "/api/fallback/models/\(name)")
    }

    func addFallbackModel(name: String) async throws -> FallbackModelResponse {
        let body = FallbackModelBody(name: name)
        return try await post(endpoint: "/api/fallback/models", body: body)
    }

    func removeFallbackModel(name: String) async throws -> RemoveFallbackModelResponse {
        try await delete(endpoint: "/api/fallback/models/\(name)")
    }

    func toggleFallbackModel(name: String, enabled: Bool) async throws -> FallbackModelResponse {
        let body = FallbackModelToggleBody(enabled: enabled)
        return try await post(endpoint: "/api/fallback/models/\(name)/toggle", body: body)
    }

    func addFallbackEntry(modelName: String, provider: String, modelId: String, priority: Int? = nil) async throws -> FallbackEntryResponse {
        let body = FallbackEntryBody(provider: provider, model_id: modelId, priority: priority)
        return try await post(endpoint: "/api/fallback/models/\(modelName)/entries", body: body)
    }

    func removeFallbackEntry(modelName: String, entryId: String) async throws -> RemoveFallbackEntryResponse {
        try await delete(endpoint: "/api/fallback/models/\(modelName)/entries/\(entryId)")
    }

    func exportFallbackConfig() async throws -> FallbackExportResponse {
        try await get(endpoint: "/api/fallback/export")
    }

    func importFallbackConfig(config: FallbackConfigImportBody) async throws -> FallbackImportResponse {
        return try await post(endpoint: "/api/fallback/import", body: config)
    }

    // MARK: - Stats Endpoints

    func fetchStats() async throws -> StatsResponse {
        try await get(endpoint: "/api/stats")
    }

    func listRequestStats(provider: String? = nil, minutes: Int? = nil) async throws -> RequestStatsResponse {
        var endpoint = "/api/stats/requests"
        var queryItems: [String] = []
        if let provider = provider {
            queryItems.append("provider=\(provider)")
        }
        if let minutes = minutes {
            queryItems.append("minutes=\(minutes)")
        }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return try await get(endpoint: endpoint)
    }

    func clearRequestStats() async throws -> ClearStatsResponse {
        try await delete(endpoint: "/api/stats/requests")
    }

    // MARK: - Logs Endpoints

    func fetchLogs(after: Int? = nil, limit: Int? = nil, provider: String? = nil) async throws -> APILogsResponse {
        var endpoint = "/api/logs"
        var queryItems: [String] = []
        if let after = after {
            queryItems.append("after=\(after)")
        }
        if let limit = limit {
            queryItems.append("limit=\(limit)")
        }
        if let provider = provider {
            queryItems.append("provider=\(provider)")
        }
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        return try await get(endpoint: endpoint)
    }

    func clearLogs() async throws -> ClearLogsResponse {
        try await delete(endpoint: "/api/logs")
    }

    // MARK: - API Keys Endpoints

    func listApiKeys() async throws -> ApiKeysListResponse {
        try await get(endpoint: "/api/keys")
    }

    func addApiKey() async throws -> ApiKeyAddResponse {
        return try await post(endpoint: "/api/keys", body: EmptyBody())
    }

    func deleteApiKey(key: String) async throws -> ApiKeyDeleteResponse {
        try await delete(endpoint: "/api/keys/\(key)")
    }

    // MARK: - Remote Mode Endpoints

    func remoteSetConfig(endpointURL: String, displayName: String? = nil, managementKey: String? = nil, verifySSL: Bool? = nil, timeoutSeconds: Int? = nil) async throws -> RemoteConfigResponse {
        let body = RemoteConfigBody(
            endpoint_url: endpointURL,
            display_name: displayName,
            management_key: managementKey,
            verify_ssl: verifySSL,
            timeout_seconds: timeoutSeconds
        )
        return try await post(endpoint: "/api/remote/config", body: body)
    }

    func remoteGetConfig() async throws -> RemoteConfigResponse {
        try await get(endpoint: "/api/remote/config")
    }

    func remoteClearConfig() async throws -> RemoteClearConfigResponse {
        try await delete(endpoint: "/api/remote/config")
    }

    func remoteTestConnection(endpointURL: String, managementKey: String? = nil, timeoutSeconds: Int? = nil) async throws -> RemoteTestConnectionResponse {
        let body = RemoteTestBody(
            endpoint_url: endpointURL,
            management_key: managementKey,
            timeout_seconds: timeoutSeconds
        )
        return try await post(endpoint: "/api/remote/test", body: body)
    }
}
