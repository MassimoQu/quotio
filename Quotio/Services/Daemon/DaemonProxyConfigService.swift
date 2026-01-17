//
//  DaemonProxyConfigService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonProxyConfigService {
    static let shared = DaemonProxyConfigService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    
    private(set) var config: ServerConfigResponse?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func fetchAllConfig() async -> ServerConfigResponse? {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.getAllConfig()
            config = result
            return result
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func getDebug() async -> Bool? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getDebugMode()
            return result.enabled
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setDebug(_ enabled: Bool) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setDebugMode(enabled)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func getRoutingStrategy() async -> String? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getRoutingStrategy()
            return result.strategy
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setRoutingStrategy(_ strategy: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setRoutingStrategy(strategy)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func getProxyURL() async -> String? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getProxyUrl()
            return result.url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setProxyURL(_ url: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setProxyUrl(url)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func deleteProxyURL() async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.deleteProxyUrl()
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func getRequestRetry() async -> Int? {
        do {
            try await ensureConnected()
            let result: APIRequestRetryResponse = try await apiClient.getRequestRetry()
            return result.requestRetry
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setRequestRetry(_ count: Int) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setRequestRetry(count)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func getMaxRetryInterval() async -> Int? {
        do {
            try await ensureConnected()
            let result: APIMaxRetryIntervalResponse = try await apiClient.getMaxRetryInterval()
            return result.maxRetryInterval
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setMaxRetryInterval(_ seconds: Int) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setMaxRetryInterval(seconds)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func getLoggingToFile() async -> Bool? {
        do {
            try await ensureConnected()
            let result: APILoggingToFileResponse = try await apiClient.getLoggingToFile()
            return result.loggingToFile
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setLoggingToFile(_ enabled: Bool) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setLoggingToFile(enabled)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func setQuotaExceededSwitchProject(_ enabled: Bool) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setQuotaExceededSwitchProject(enabled)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func setQuotaExceededSwitchPreviewModel(_ enabled: Bool) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setQuotaExceededSwitchPreviewModel(enabled)
        } catch {
            lastError = error.localizedDescription
            throw DaemonProxyConfigError.updateFailed(error.localizedDescription)
        }
    }
    
    func setRequestLog(_ enabled: Bool) async throws {
        // TODO: Server doesn't have request-log endpoint yet - stub for compatibility
    }
    
    func reset() {
        config = nil
        lastError = nil
    }
}

enum DaemonProxyConfigError: LocalizedError {
    case daemonNotRunning
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .daemonNotRunning:
            return "Daemon is not running"
        case .updateFailed(let reason):
            return "Failed to update proxy config: \(reason)"
        }
    }
}
