//
//  QuotioAPITypes.swift
//  Quotio
//

import Foundation

// MARK: - Connection State

enum APIConnectionState: Sendable, CustomStringConvertible {
    case disconnected
    case connecting
    case connected
    case failed(String)

    nonisolated var description: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .failed(let reason): return "failed(\(reason))"
        }
    }
}

// MARK: - API Client Error

enum APIClientError: LocalizedError, Sendable {
    case serverNotRunning
    case connectionFailed(String)
    case notConnected
    case disconnected
    case timeout
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case requestFailed(String)

    nonisolated var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Server is not running"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .notConnected:
            return "Not connected to server"
        case .disconnected:
            return "Disconnected from server"
        case .timeout:
            return "Request timed out"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        }
    }
}

// MARK: - Response Types

struct HealthResponse: Decodable, Sendable {
    let status: String
    let version: String
    let timestamp: String
    let uptime: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        version = try container.decode(String.self, forKey: .version)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        uptime = try container.decode(Int.self, forKey: .uptime)
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, version, timestamp, uptime
    }
}

struct StatusResponse: Decodable, Sendable {
    let status: String
    let version: String
    let runtime: String
    let timestamp: String
    let uptime: Int
    let server: ServerInfo
    let system: SystemInfo
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        version = try container.decode(String.self, forKey: .version)
        runtime = try container.decode(String.self, forKey: .runtime)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        uptime = try container.decode(Int.self, forKey: .uptime)
        server = try container.decode(ServerInfo.self, forKey: .server)
        system = try container.decode(SystemInfo.self, forKey: .system)
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, version, runtime, timestamp, uptime, server, system
    }
}

struct ServerInfo: Decodable, Sendable {
    let port: Int
    let host: String
    let debug: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        port = try container.decode(Int.self, forKey: .port)
        host = try container.decode(String.self, forKey: .host)
        debug = try container.decode(Bool.self, forKey: .debug)
    }
    
    private enum CodingKeys: String, CodingKey {
        case port, host, debug
    }
}

struct SystemInfo: Decodable, Sendable {
    let platform: String
    let arch: String
    let nodeVersion: String
    let memory: MemoryInfo
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platform = try container.decode(String.self, forKey: .platform)
        arch = try container.decode(String.self, forKey: .arch)
        nodeVersion = try container.decode(String.self, forKey: .nodeVersion)
        memory = try container.decode(MemoryInfo.self, forKey: .memory)
    }
    
    private enum CodingKeys: String, CodingKey {
        case platform, arch, nodeVersion, memory
    }
}

struct MemoryInfo: Decodable, Sendable {
    let heapUsed: Int64
    let heapTotal: Int64
    let rss: Int64
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        heapUsed = try container.decode(Int64.self, forKey: .heapUsed)
        heapTotal = try container.decode(Int64.self, forKey: .heapTotal)
        rss = try container.decode(Int64.self, forKey: .rss)
    }
    
    private enum CodingKeys: String, CodingKey {
        case heapUsed, heapTotal, rss
    }
}

struct ProxyStatusResponse: Decodable, Sendable {
    let running: Bool
    let port: Int
    let version: String
    let uptime: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        running = try container.decode(Bool.self, forKey: .running)
        port = try container.decode(Int.self, forKey: .port)
        version = try container.decode(String.self, forKey: .version)
        uptime = try container.decode(Int.self, forKey: .uptime)
    }
    
    private enum CodingKeys: String, CodingKey {
        case running, port, version, uptime
    }
}

struct ProxyStartResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let port: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
        port = try container.decode(Int.self, forKey: .port)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, port
    }
}

struct ProxyStopResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message
    }
}

struct ServerLatestVersionResponse: Decodable, Sendable {
    let currentVersion: String?
    let latestVersion: String?
    let isLatest: Bool?
    let releaseUrl: String?
    let publishedAt: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentVersion = try container.decodeIfPresent(String.self, forKey: .currentVersion)
        latestVersion = try container.decodeIfPresent(String.self, forKey: .latestVersion)
        isLatest = try container.decodeIfPresent(Bool.self, forKey: .isLatest)
        releaseUrl = try container.decodeIfPresent(String.self, forKey: .releaseUrl)
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case currentVersion, latestVersion, isLatest, releaseUrl, publishedAt
    }
}

// MARK: - Auth Response Types

struct AuthListResponse: Decodable, Sendable {
    let auth_files: [AuthFileInfoAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auth_files = try container.decode([AuthFileInfoAPI].self, forKey: .auth_files)
    }
    
    private enum CodingKeys: String, CodingKey {
        case auth_files
    }
}

struct AuthFileInfoAPI: Decodable, Sendable {
    let id: String
    let provider: String
    let email: String?
    let name: String?
    let status: String?
    let disabled: Bool
    let expires_at: String?
    let is_expired: Bool?
    let created_at: String?
    let updated_at: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(String.self, forKey: .provider)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        disabled = try container.decode(Bool.self, forKey: .disabled)
        expires_at = try container.decodeIfPresent(String.self, forKey: .expires_at)
        is_expired = try container.decodeIfPresent(Bool.self, forKey: .is_expired)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, provider, email, name, status, disabled, expires_at, is_expired, created_at, updated_at
    }
}

struct DeleteAuthResponse: Decodable, Sendable {
    let success: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success
    }
}

struct DeleteAllAuthResponse: Decodable, Sendable {
    let success: Bool
    let deleted: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        deleted = try container.decode(Int.self, forKey: .deleted)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, deleted
    }
}

struct SetDisabledResponse: Decodable, Sendable {
    let success: Bool
    let id: String
    let disabled: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        id = try container.decode(String.self, forKey: .id)
        disabled = try container.decode(Bool.self, forKey: .disabled)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, id, disabled
    }
}

struct AuthModelsResponse: Decodable, Sendable {
    let models: [AuthModelInfo]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        models = try container.decode([AuthModelInfo].self, forKey: .models)
    }
    
    private enum CodingKeys: String, CodingKey {
        case models
    }
}

struct AuthModelInfo: Decodable, Sendable {
    let id: String
    let name: String
    let owned_by: String?
    let provider: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        owned_by = try container.decodeIfPresent(String.self, forKey: .owned_by)
        provider = try container.decode(String.self, forKey: .provider)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, owned_by, provider
    }
}

// MARK: - OAuth Response Types

struct OAuthStartResponse: Decodable, Sendable {
    let auth_url: String
    let state: String
    let incognito: Bool?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auth_url = try container.decode(String.self, forKey: .auth_url)
        state = try container.decode(String.self, forKey: .state)
        incognito = try container.decodeIfPresent(Bool.self, forKey: .incognito)
    }
    
    private enum CodingKeys: String, CodingKey {
        case auth_url, state, incognito
    }
}

struct OAuthPollResponse: Decodable, Sendable {
    let status: String
    let provider: String?
    let email: String?
    let error: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, provider, email, error
    }
}

struct DeviceCodeResponse: Decodable, Sendable {
    let device_code: String
    let user_code: String
    let verification_uri: String
    let expires_in: Int
    let interval: Int?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        device_code = try container.decode(String.self, forKey: .device_code)
        user_code = try container.decode(String.self, forKey: .user_code)
        verification_uri = try container.decode(String.self, forKey: .verification_uri)
        expires_in = try container.decode(Int.self, forKey: .expires_in)
        interval = try container.decodeIfPresent(Int.self, forKey: .interval)
    }
    
    private enum CodingKeys: String, CodingKey {
        case device_code, user_code, verification_uri, expires_in, interval
    }
}

struct DeviceCodePollResponse: Decodable, Sendable {
    let status: String
    let provider: String?
    let email: String?
    let error: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case status, provider, email, error
    }
}

struct RefreshTokenResponse: Decodable, Sendable {
    let success: Bool
    let refreshed: Int
    let errors: [RefreshError]?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        refreshed = try container.decode(Int.self, forKey: .refreshed)
        errors = try container.decodeIfPresent([RefreshError].self, forKey: .errors)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, refreshed, errors
    }
}

struct RefreshError: Decodable, Sendable {
    let id: String
    let error: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        error = try container.decode(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, error
    }
}

struct OAuthCancelResponse: Decodable, Sendable {
    let success: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success
    }
}

// MARK: - Quota Response Types

struct QuotaFetchResponse: Decodable, Sendable {
    let provider: String?
    let quotas: [QuotaInfoAPI]
    let refreshed: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        quotas = try container.decode([QuotaInfoAPI].self, forKey: .quotas)
        refreshed = try container.decode(Bool.self, forKey: .refreshed)
    }
    
    private enum CodingKeys: String, CodingKey {
        case provider, quotas, refreshed
    }
}

struct QuotaInfoAPI: Decodable, Sendable {
    let id: String
    let provider: String
    let email: String?
    let used: Int64?
    let limit: Int64?
    let remaining: Int64?
    let percent_used: Double?
    let last_updated: String?
    let error: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(String.self, forKey: .provider)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        used = try container.decodeIfPresent(Int64.self, forKey: .used)
        limit = try container.decodeIfPresent(Int64.self, forKey: .limit)
        remaining = try container.decodeIfPresent(Int64.self, forKey: .remaining)
        percent_used = try container.decodeIfPresent(Double.self, forKey: .percent_used)
        last_updated = try container.decodeIfPresent(String.self, forKey: .last_updated)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, provider, email, used, limit, remaining, percent_used, last_updated, error
    }
}

struct QuotaListResponse: Decodable, Sendable {
    let quotas: [QuotaInfoAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quotas = try container.decode([QuotaInfoAPI].self, forKey: .quotas)
    }
    
    private enum CodingKeys: String, CodingKey {
        case quotas
    }
}

struct QuotaRefreshResponse: Decodable, Sendable {
    let success: Bool
    let refreshed_count: Int
    let errors: [String]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        refreshed_count = try container.decode(Int.self, forKey: .refreshed_count)
        errors = try container.decode([String].self, forKey: .errors)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, refreshed_count, errors
    }
}

// MARK: - Agent Response Types

struct AgentDetectResponse: Decodable, Sendable {
    let agents: [AgentInfoAPI]
    let detected_at: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agents = try container.decode([AgentInfoAPI].self, forKey: .agents)
        detected_at = try container.decode(String.self, forKey: .detected_at)
    }
    
    private enum CodingKeys: String, CodingKey {
        case agents, detected_at
    }
}

struct AgentInfoAPI: Decodable, Sendable {
    let id: String
    let name: String
    let version: String?
    let installed: Bool
    let configured: Bool
    let config_path: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        installed = try container.decode(Bool.self, forKey: .installed)
        configured = try container.decode(Bool.self, forKey: .configured)
        config_path = try container.decodeIfPresent(String.self, forKey: .config_path)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, version, installed, configured, config_path
    }
}

struct AgentConfigureResponse: Decodable, Sendable {
    let success: Bool
    let configType: String
    let mode: String
    let configPath: String?
    let backupPath: String?
    let instructions: String
    let modelsConfigured: Int
    let error: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        configType = try container.decode(String.self, forKey: .configType)
        mode = try container.decode(String.self, forKey: .mode)
        configPath = try container.decodeIfPresent(String.self, forKey: .configPath)
        backupPath = try container.decodeIfPresent(String.self, forKey: .backupPath)
        instructions = try container.decode(String.self, forKey: .instructions)
        modelsConfigured = try container.decode(Int.self, forKey: .modelsConfigured)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, configType, mode, configPath, backupPath, instructions, modelsConfigured, error
    }
}

// MARK: - Config Response Types

struct APIProxyURLResponse: Decodable, Sendable {
    let url: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decodeIfPresent(String.self, forKey: .url)
    }
    
    private enum CodingKeys: String, CodingKey {
        case url
    }
}

struct APIRoutingStrategyResponse: Decodable, Sendable {
    let strategy: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strategy = try container.decode(String.self, forKey: .strategy)
    }
    
    private enum CodingKeys: String, CodingKey {
        case strategy
    }
}

struct DebugModeResponse: Decodable, Sendable {
    let enabled: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
    }
    
    private enum CodingKeys: String, CodingKey {
        case enabled
    }
}

struct ManagementKeyResponse: Decodable, Sendable {
    let has_key: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        has_key = try container.decode(Bool.self, forKey: .has_key)
    }
    
    private enum CodingKeys: String, CodingKey {
        case has_key
    }
}

struct SetManagementKeyResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message
    }
}

// MARK: - Server Config Response (Full Config)

struct ServerConfigResponse: Decodable, Sendable {
    let host: String
    let port: Int
    let authDir: String
    let proxyUrl: String
    let apiKeys: [String]
    let debug: Bool
    let loggingToFile: Bool
    let usageStatisticsEnabled: Bool
    let requestRetry: Int
    let maxRetryInterval: Int
    let wsAuth: Bool
    let routing: ServerRoutingConfig
    let quotaExceeded: ServerQuotaExceededConfig
    let remoteManagement: ServerRemoteManagementConfig
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        authDir = try container.decode(String.self, forKey: .authDir)
        proxyUrl = try container.decodeIfPresent(String.self, forKey: .proxyUrl) ?? ""
        apiKeys = try container.decodeIfPresent([String].self, forKey: .apiKeys) ?? []
        debug = try container.decode(Bool.self, forKey: .debug)
        loggingToFile = try container.decode(Bool.self, forKey: .loggingToFile)
        usageStatisticsEnabled = try container.decode(Bool.self, forKey: .usageStatisticsEnabled)
        requestRetry = try container.decode(Int.self, forKey: .requestRetry)
        maxRetryInterval = try container.decode(Int.self, forKey: .maxRetryInterval)
        wsAuth = try container.decode(Bool.self, forKey: .wsAuth)
        routing = try container.decode(ServerRoutingConfig.self, forKey: .routing)
        quotaExceeded = try container.decode(ServerQuotaExceededConfig.self, forKey: .quotaExceeded)
        remoteManagement = try container.decode(ServerRemoteManagementConfig.self, forKey: .remoteManagement)
    }
    
    private enum CodingKeys: String, CodingKey {
        case host, port, debug, routing
        case authDir = "auth-dir"
        case proxyUrl = "proxy-url"
        case apiKeys = "api-keys"
        case loggingToFile = "logging-to-file"
        case usageStatisticsEnabled = "usage-statistics-enabled"
        case requestRetry = "request-retry"
        case maxRetryInterval = "max-retry-interval"
        case wsAuth = "ws-auth"
        case quotaExceeded = "quota-exceeded"
        case remoteManagement = "remote-management"
    }
}

struct ServerRoutingConfig: Decodable, Sendable {
    let strategy: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strategy = try container.decode(String.self, forKey: .strategy)
    }
    
    private enum CodingKeys: String, CodingKey {
        case strategy
    }
}

struct ServerQuotaExceededConfig: Decodable, Sendable {
    let switchProject: Bool
    let switchPreviewModel: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switchProject = try container.decode(Bool.self, forKey: .switchProject)
        switchPreviewModel = try container.decode(Bool.self, forKey: .switchPreviewModel)
    }
    
    private enum CodingKeys: String, CodingKey {
        case switchProject = "switch-project"
        case switchPreviewModel = "switch-preview-model"
    }
}

struct ServerRemoteManagementConfig: Decodable, Sendable {
    let allowRemote: Bool
    let secretKey: String
    let disableControlPanel: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowRemote = try container.decode(Bool.self, forKey: .allowRemote)
        secretKey = try container.decodeIfPresent(String.self, forKey: .secretKey) ?? ""
        disableControlPanel = try container.decode(Bool.self, forKey: .disableControlPanel)
    }
    
    private enum CodingKeys: String, CodingKey {
        case allowRemote = "allow-remote"
        case secretKey = "secret-key"
        case disableControlPanel = "disable-control-panel"
    }
}

struct APIRequestRetryResponse: Decodable, Sendable {
    let requestRetry: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestRetry = try container.decode(Int.self, forKey: .requestRetry)
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestRetry = "request_retry"
    }
}

struct APIMaxRetryIntervalResponse: Decodable, Sendable {
    let maxRetryInterval: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxRetryInterval = try container.decode(Int.self, forKey: .maxRetryInterval)
    }
    
    private enum CodingKeys: String, CodingKey {
        case maxRetryInterval = "max_retry_interval"
    }
}

struct APILoggingToFileResponse: Decodable, Sendable {
    let loggingToFile: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        loggingToFile = try container.decode(Bool.self, forKey: .loggingToFile)
    }
    
    private enum CodingKeys: String, CodingKey {
        case loggingToFile = "logging_to_file"
    }
}

struct ConfigSuccessResponse: Decodable, Sendable {
    let success: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success
    }
}

// MARK: - Fallback Response Types

struct FallbackConfigResponse: Decodable, Sendable {
    let is_enabled: Bool
    let virtual_models: [VirtualModelAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        is_enabled = try container.decode(Bool.self, forKey: .is_enabled)
        virtual_models = try container.decode([VirtualModelAPI].self, forKey: .virtual_models)
    }
    
    private enum CodingKeys: String, CodingKey {
        case is_enabled, virtual_models
    }
}

struct VirtualModelAPI: Decodable, Sendable {
    let id: String
    let name: String
    let fallback_entries: [FallbackEntryAPI]
    let is_enabled: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fallback_entries = try container.decode([FallbackEntryAPI].self, forKey: .fallback_entries)
        is_enabled = try container.decode(Bool.self, forKey: .is_enabled)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, fallback_entries, is_enabled
    }
}

struct FallbackEntryAPI: Decodable, Sendable {
    let id: String
    let provider: String
    let model_id: String
    let priority: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        provider = try container.decode(String.self, forKey: .provider)
        model_id = try container.decode(String.self, forKey: .model_id)
        priority = try container.decode(Int.self, forKey: .priority)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, provider, model_id, priority
    }
}

struct FallbackEnabledResponse: Decodable, Sendable {
    let is_enabled: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        is_enabled = try container.decode(Bool.self, forKey: .is_enabled)
    }
    
    private enum CodingKeys: String, CodingKey {
        case is_enabled
    }
}

struct FallbackModelsResponse: Decodable, Sendable {
    let models: [VirtualModelAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        models = try container.decode([VirtualModelAPI].self, forKey: .models)
    }
    
    private enum CodingKeys: String, CodingKey {
        case models
    }
}

struct FallbackModelResponse: Decodable, Sendable {
    let model: VirtualModelAPI
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try container.decode(VirtualModelAPI.self, forKey: .model)
    }
    
    private enum CodingKeys: String, CodingKey {
        case model
    }
}

struct RemoveFallbackModelResponse: Decodable, Sendable {
    let success: Bool
    let deleted_name: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        deleted_name = try container.decode(String.self, forKey: .deleted_name)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, deleted_name
    }
}

struct FallbackEntryResponse: Decodable, Sendable {
    let success: Bool
    let model_name: String
    let entry: FallbackEntryAPI
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        model_name = try container.decode(String.self, forKey: .model_name)
        entry = try container.decode(FallbackEntryAPI.self, forKey: .entry)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, model_name, entry
    }
}

struct RemoveFallbackEntryResponse: Decodable, Sendable {
    let success: Bool
    let deleted_entry_id: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        deleted_entry_id = try container.decode(String.self, forKey: .deleted_entry_id)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, deleted_entry_id
    }
}

struct FallbackExportResponse: Decodable, Sendable {
    let config: FallbackConfigResponse
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        config = try container.decode(FallbackConfigResponse.self, forKey: .config)
    }
    
    private enum CodingKeys: String, CodingKey {
        case config
    }
}

struct FallbackImportResponse: Decodable, Sendable {
    let success: Bool
    let imported_count: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        imported_count = try container.decode(Int.self, forKey: .imported_count)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, imported_count
    }
}

// MARK: - Stats Response Types

struct StatsResponse: Decodable, Sendable {
    let total_requests: Int
    let successful_requests: Int
    let failed_requests: Int
    let total_tokens: Int64
    let average_latency_ms: Double
    let provider_stats: [ProviderStatsAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total_requests = try container.decode(Int.self, forKey: .total_requests)
        successful_requests = try container.decode(Int.self, forKey: .successful_requests)
        failed_requests = try container.decode(Int.self, forKey: .failed_requests)
        total_tokens = try container.decode(Int64.self, forKey: .total_tokens)
        average_latency_ms = try container.decode(Double.self, forKey: .average_latency_ms)
        provider_stats = try container.decode([ProviderStatsAPI].self, forKey: .provider_stats)
    }
    
    private enum CodingKeys: String, CodingKey {
        case total_requests, successful_requests, failed_requests, total_tokens, average_latency_ms, provider_stats
    }
}

struct ProviderStatsAPI: Decodable, Sendable {
    let provider: String
    let requests: Int
    let tokens: Int64
    let success_rate: Double
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(String.self, forKey: .provider)
        requests = try container.decode(Int.self, forKey: .requests)
        tokens = try container.decode(Int64.self, forKey: .tokens)
        success_rate = try container.decode(Double.self, forKey: .success_rate)
    }
    
    private enum CodingKeys: String, CodingKey {
        case provider, requests, tokens, success_rate
    }
}

struct RequestStatsResponse: Decodable, Sendable {
    let requests: [RequestInfoAPI]
    let total: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requests = try container.decode([RequestInfoAPI].self, forKey: .requests)
        total = try container.decode(Int.self, forKey: .total)
    }
    
    private enum CodingKeys: String, CodingKey {
        case requests, total
    }
}

struct RequestInfoAPI: Decodable, Sendable {
    let id: String
    let timestamp: String
    let provider: String
    let model: String
    let status: String
    let latency_ms: Double
    let tokens: Int?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        provider = try container.decode(String.self, forKey: .provider)
        model = try container.decode(String.self, forKey: .model)
        status = try container.decode(String.self, forKey: .status)
        latency_ms = try container.decode(Double.self, forKey: .latency_ms)
        tokens = try container.decodeIfPresent(Int.self, forKey: .tokens)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, timestamp, provider, model, status, latency_ms, tokens
    }
}

struct ClearStatsResponse: Decodable, Sendable {
    let success: Bool
    let cleared_count: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        cleared_count = try container.decode(Int.self, forKey: .cleared_count)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, cleared_count
    }
}

// MARK: - Logs Response Types

struct APILogsResponse: Decodable, Sendable {
    let logs: [APILogEntry]
    let count: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logs = try container.decode([APILogEntry].self, forKey: .logs)
        count = try container.decode(Int.self, forKey: .count)
    }
    
    private enum CodingKeys: String, CodingKey {
        case logs, count
    }
}

/// Request log entry from server - matches RequestLogEntry in request-logger.ts
struct APILogEntry: Decodable, Sendable {
    let requestId: String
    let timestamp: String
    let method: String
    let path: String
    let query: [String: String]?
    let status: Int?
    let durationMs: Int?
    let provider: String?
    let model: String?
    let error: String?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        requestId = try container.decode(String.self, forKey: .requestId)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        method = try container.decode(String.self, forKey: .method)
        path = try container.decode(String.self, forKey: .path)
        query = try container.decodeIfPresent([String: String].self, forKey: .query)
        status = try container.decodeIfPresent(Int.self, forKey: .status)
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case requestId, timestamp, method, path, query, status, durationMs, provider, model, error
    }
}

struct ClearLogsResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message
    }
}

// MARK: - API Keys Response Types

struct ApiKeysListResponse: Decodable, Sendable {
    let keys: [ApiKeyInfoAPI]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keys = try container.decode([ApiKeyInfoAPI].self, forKey: .keys)
    }
    
    private enum CodingKeys: String, CodingKey {
        case keys
    }
}

struct ApiKeyInfoAPI: Decodable, Sendable {
    let key: String
    let created_at: String
    let last_used: String?
    let usage_count: Int
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        created_at = try container.decode(String.self, forKey: .created_at)
        last_used = try container.decodeIfPresent(String.self, forKey: .last_used)
        usage_count = try container.decode(Int.self, forKey: .usage_count)
    }
    
    private enum CodingKeys: String, CodingKey {
        case key, created_at, last_used, usage_count
    }
}

struct ApiKeyAddResponse: Decodable, Sendable {
    let success: Bool
    let key: String
    let created_at: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        key = try container.decode(String.self, forKey: .key)
        created_at = try container.decode(String.self, forKey: .created_at)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, key, created_at
    }
}

struct ApiKeyDeleteResponse: Decodable, Sendable {
    let success: Bool
    let deleted_key: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        deleted_key = try container.decode(String.self, forKey: .deleted_key)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, deleted_key
    }
}

// MARK: - Remote Mode Response Types

struct RemoteConfigResponse: Decodable, Sendable {
    let endpoint_url: String?
    let display_name: String?
    let connected: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endpoint_url = try container.decodeIfPresent(String.self, forKey: .endpoint_url)
        display_name = try container.decodeIfPresent(String.self, forKey: .display_name)
        connected = try container.decode(Bool.self, forKey: .connected)
    }
    
    private enum CodingKeys: String, CodingKey {
        case endpoint_url, display_name, connected
    }
}

struct RemoteClearConfigResponse: Decodable, Sendable {
    let success: Bool
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success
    }
}

struct RemoteTestConnectionResponse: Decodable, Sendable {
    let success: Bool
    let message: String
    let latency_ms: Double?
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decode(String.self, forKey: .message)
        latency_ms = try container.decodeIfPresent(Double.self, forKey: .latency_ms)
    }
    
    private enum CodingKeys: String, CodingKey {
        case success, message, latency_ms
    }
}

// MARK: - Request Body Types

struct EmptyBody: Encodable, Sendable {}

struct DisabledBody: Encodable, Sendable {
    let disabled: Bool
}

struct CancelOAuthBody: Encodable, Sendable {
    let state: String
}

struct CancelDeviceCodeBody: Encodable, Sendable {
    let device_code: String
}

struct RefreshBody: Encodable, Sendable {
    let provider: String?
}

struct OAuthStartBody: Encodable, Sendable {
    let provider: String
    let project_id: String?
    let is_web_ui: Bool
}

struct DeviceCodeBody: Encodable, Sendable {
    let provider: String
}

struct DeviceCodePollBody: Encodable, Sendable {
    let device_code: String
}

struct AgentConfigBody: Encodable, Sendable {
    let config: [String: String]?
}

struct ConfigureAgentBody: Encodable, Sendable {
    let mode: String
    let config: AgentConfigBody?
}

struct ProxyURLBody: Encodable, Sendable {
    let url: String?
}

struct RoutingStrategyBody: Encodable, Sendable {
    let strategy: String
}

struct DebugModeBody: Encodable, Sendable {
    let enabled: Bool
}

struct ManagementKeyBody: Encodable, Sendable {
    let key: String
}

struct ConfigValueBody<T: Encodable & Sendable>: Encodable, Sendable {
    let value: T
}

struct FallbackEnabledBody: Encodable, Sendable {
    let enabled: Bool
}

struct FallbackModelBody: Encodable, Sendable {
    let name: String
}

struct FallbackModelToggleBody: Encodable, Sendable {
    let enabled: Bool
}

struct FallbackEntryBody: Encodable, Sendable {
    let provider: String
    let model_id: String
    let priority: Int?
}

struct FallbackConfigImportBody: Encodable, Sendable {
    let is_enabled: Bool
    let virtual_models: [FallbackConfigVirtualModel]
}

struct FallbackConfigVirtualModel: Encodable, Sendable {
    let id: String
    let name: String
    let fallback_entries: [FallbackConfigEntry]
    let is_enabled: Bool
}

struct FallbackConfigEntry: Encodable, Sendable {
    let id: String
    let provider: String
    let model_id: String
    let priority: Int
}

struct RemoteConfigBody: Encodable, Sendable {
    let endpoint_url: String
    let display_name: String?
    let management_key: String?
    let verify_ssl: Bool?
    let timeout_seconds: Int?
}

struct RemoteTestBody: Encodable, Sendable {
    let endpoint_url: String
    let management_key: String?
    let timeout_seconds: Int?
}

// MARK: - Empty Response

struct EmptyResponse: Decodable, Sendable {
    nonisolated init(from decoder: any Decoder) throws {}
}

// MARK: - Auth Token Response

struct AuthTokenResponse: Decodable, Sendable {
    let access_token: String
    let expires_at: String?
    let provider: String
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        access_token = try container.decode(String.self, forKey: .access_token)
        expires_at = try container.decodeIfPresent(String.self, forKey: .expires_at)
        provider = try container.decode(String.self, forKey: .provider)
    }
    
    private enum CodingKeys: String, CodingKey {
        case access_token, expires_at, provider
    }
}

// MARK: - Copilot Available Models Response

struct CopilotAvailableModelsResponse: Decodable, Sendable {
    let model_ids: [String]
    
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model_ids = try container.decode([String].self, forKey: .model_ids)
    }
    
    private enum CodingKeys: String, CodingKey {
        case model_ids
    }
}
