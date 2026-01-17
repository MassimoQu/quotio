//
//  DaemonLogsService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonLogsService {
    static let shared = DaemonLogsService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var logEntries: [IPCLogEntry] = []
    private(set) var lastRequestId: String?
    
    /// Last log entry ID for pagination - derived from lastRequestId hash
    var lastId: Int? {
        lastRequestId?.hashValue
    }
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    func fetchLogs(after: Int? = nil, limit: Int = 100) async -> [IPCLogEntry] {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await apiClient.connect()
            let result = try await apiClient.fetchLogs(after: after, limit: limit)
            
            let entries = result.logs.map { convertToIPCLogEntry($0) }
            logEntries = entries
            lastRequestId = result.logs.last?.requestId
            
            return entries
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
    
    func clearLogs() async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await apiClient.connect()
            let result = try await apiClient.clearLogs()
            if result.success {
                logEntries = []
                lastRequestId = nil
            } else {
                throw DaemonLogsError.clearFailed
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func refreshLogs() async {
        _ = await fetchLogs()
    }
    
    func reset() {
        logEntries = []
        lastRequestId = nil
        lastError = nil
    }
    
    private func convertToIPCLogEntry(_ entry: APILogEntry) -> IPCLogEntry {
        IPCLogEntry(
            id: entry.requestId.hashValue,
            timestamp: entry.timestamp,
            method: entry.method,
            path: entry.path,
            statusCode: entry.status ?? 0,
            duration: entry.durationMs ?? 0,
            provider: entry.provider,
            model: entry.model,
            inputTokens: nil,
            outputTokens: nil,
            error: entry.error
        )
    }
}

enum DaemonLogsError: LocalizedError {
    case daemonNotRunning
    case clearFailed
    
    var errorDescription: String? {
        switch self {
        case .daemonNotRunning:
            return "Daemon is not running"
        case .clearFailed:
            return "Failed to clear logs"
        }
    }
}
