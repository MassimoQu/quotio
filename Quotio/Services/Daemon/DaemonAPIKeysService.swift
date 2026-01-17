//
//  DaemonAPIKeysService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonAPIKeysService {
    static let shared = DaemonAPIKeysService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    
    private(set) var apiKeys: [String] = []
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func fetchAPIKeys() async -> [String] {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.listApiKeys()
            apiKeys = result.keys.map { $0.key }
            return apiKeys
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
    
    func addAPIKey() async throws -> String? {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.addApiKey()
            if result.success {
                apiKeys.append(result.key)
                return result.key
            } else {
                throw DaemonAPIKeysError.addFailed("Server returned success: false")
            }
        } catch let error as DaemonAPIKeysError {
            lastError = error.localizedDescription
            throw error
        } catch {
            lastError = error.localizedDescription
            throw DaemonAPIKeysError.addFailed(error.localizedDescription)
        }
    }
    
    func deleteAPIKey(_ key: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.deleteApiKey(key: key)
            if result.success {
                apiKeys.removeAll { $0 == key }
            } else {
                throw DaemonAPIKeysError.deleteFailed("Server returned success: false")
            }
        } catch let error as DaemonAPIKeysError {
            lastError = error.localizedDescription
            throw error
        } catch {
            lastError = error.localizedDescription
            throw DaemonAPIKeysError.deleteFailed(error.localizedDescription)
        }
    }
    
    func reset() {
        apiKeys = []
        lastError = nil
    }
}

enum DaemonAPIKeysError: LocalizedError {
    case daemonNotRunning
    case addFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .daemonNotRunning:
            return "Daemon is not running"
        case .addFailed(let reason):
            return "Failed to add API key: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete API key: \(reason)"
        }
    }
}
