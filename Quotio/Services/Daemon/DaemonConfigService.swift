//
//  DaemonConfigService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonConfigService {
    static let shared = DaemonConfigService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    
    private(set) var routingStrategy: String?
    private(set) var debugMode: Bool?
    private(set) var proxyUrl: String?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func getRoutingStrategy() async -> String? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getRoutingStrategy()
            routingStrategy = result.strategy
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
            routingStrategy = strategy
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func getDebugMode() async -> Bool? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getDebugMode()
            debugMode = result.enabled
            return result.enabled
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setDebugMode(_ enabled: Bool) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            _ = try await apiClient.setDebugMode(enabled)
            debugMode = enabled
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func getProxyUrl() async -> String? {
        do {
            try await ensureConnected()
            let result = try await apiClient.getProxyUrl()
            proxyUrl = result.url
            return result.url
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func setProxyUrl(_ url: String?) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            if let url = url, !url.isEmpty {
                _ = try await apiClient.setProxyUrl(url)
                proxyUrl = url
            } else {
                _ = try await apiClient.deleteProxyUrl()
                proxyUrl = nil
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func refreshAll() async {
        _ = await getRoutingStrategy()
        _ = await getDebugMode()
        _ = await getProxyUrl()
    }
}

enum DaemonConfigError: LocalizedError {
    case daemonNotRunning
    case updateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .daemonNotRunning:
            return "Daemon is not running"
        case .updateFailed(let key):
            return "Failed to update config: \(key)"
        }
    }
}
