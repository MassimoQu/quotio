//
//  DaemonStatsService.swift
//  Quotio
//

import Foundation
import Observation

enum DaemonStatsError: LocalizedError {
    case serverNotRunning
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Server is not running"
        case .fetchFailed(let reason):
            return "Failed to fetch stats: \(reason)"
        }
    }
}

@MainActor @Observable
final class DaemonStatsService {
    static let shared = DaemonStatsService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var cachedStats: UsageStats?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func fetchUsageStats() async -> UsageStats? {
        do {
            try await ensureConnected()
        } catch {
            lastError = "Server not running"
            return nil
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.fetchStats()
            let stats = convertToUsageStats(result)
            cachedStats = stats
            return stats
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func fetchRequestStats() async -> RequestStats? {
        do {
            try await ensureConnected()
        } catch {
            lastError = "Server not running"
            return nil
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.fetchStats()
            return convertToRequestStats(result)
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func fetchRequestLogs(provider: String? = nil, minutes: Int? = nil) async -> [RequestLog]? {
        do {
            try await ensureConnected()
        } catch {
            lastError = "Server not running"
            return nil
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.listRequestStats(provider: provider, minutes: minutes)
            return result.requests.map { convertToRequestLog($0) }
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    func clearRequestStats() async throws -> Bool {
        try await ensureConnected()
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.clearRequestStats()
            return result.success
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    private func convertToUsageStats(_ response: StatsResponse) -> UsageStats {
        let inputTokens = response.provider_stats.reduce(0) { $0 + Int($1.tokens) / 2 }
        let outputTokens = response.provider_stats.reduce(0) { $0 + Int($1.tokens) / 2 }
        
        let usageData = UsageData(
            totalRequests: response.total_requests,
            successCount: response.successful_requests,
            failureCount: response.failed_requests,
            totalTokens: Int(response.total_tokens),
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
        
        return UsageStats(
            usage: usageData,
            failedRequests: response.failed_requests
        )
    }
    
    private func convertToRequestStats(_ response: StatsResponse) -> RequestStats {
        let providerStats: [String: ProviderStats] = response.provider_stats.reduce(into: [:]) { result, stat in
            result[stat.provider] = ProviderStats(
                provider: stat.provider,
                requestCount: stat.requests,
                inputTokens: Int(stat.tokens) / 2,
                outputTokens: Int(stat.tokens) / 2,
                averageDurationMs: Int(response.average_latency_ms)
            )
        }
        
        return RequestStats(
            totalRequests: response.total_requests,
            successfulRequests: response.successful_requests,
            failedRequests: response.failed_requests,
            totalInputTokens: Int(response.total_tokens) / 2,
            totalOutputTokens: Int(response.total_tokens) / 2,
            averageDurationMs: Int(response.average_latency_ms),
            byProvider: providerStats,
            byModel: [:]
        )
    }
    
    private func convertToRequestLog(_ entry: RequestInfoAPI) -> RequestLog {
        let timestamp = parseTimestamp(entry.timestamp) ?? Date()
        return RequestLog(
            id: UUID(uuidString: entry.id) ?? UUID(),
            timestamp: timestamp,
            method: "POST",
            endpoint: "/v1/chat/completions",
            provider: entry.provider,
            model: entry.model,
            inputTokens: entry.tokens ?? 0,
            outputTokens: 0,
            durationMs: Int(entry.latency_ms),
            statusCode: entry.status == "success" ? 200 : 500,
            requestSize: 0,
            responseSize: 0,
            errorMessage: entry.status == "success" ? nil : entry.status
        )
    }
    
    private func parseTimestamp(_ isoString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }
    
    func reset() {
        cachedStats = nil
        lastError = nil
    }
}
