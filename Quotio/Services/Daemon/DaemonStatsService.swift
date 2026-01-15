//
//  DaemonStatsService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonStatsService {
    static let shared = DaemonStatsService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var cachedStats: UsageStats?
    
    private let ipcClient = DaemonIPCClient.shared
    private let daemonManager = DaemonManager.shared
    
    private init() {}
    
    private var isDaemonReady: Bool {
        get async {
            if daemonManager.isRunning { return true }
            return await daemonManager.checkHealth()
        }
    }
    
    func fetchUsageStats() async -> UsageStats? {
        guard await isDaemonReady else {
            lastError = "Daemon not running"
            return nil
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await ipcClient.fetchStats()
            let stats = convertToUsageStats(result.stats)
            cachedStats = stats
            return stats
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    private func convertToUsageStats(_ ipcStats: IPCRequestStats) -> UsageStats {
        let usageData = UsageData(
            totalRequests: ipcStats.totalRequests,
            successCount: ipcStats.successfulRequests,
            failureCount: ipcStats.failedRequests,
            totalTokens: ipcStats.totalInputTokens + ipcStats.totalOutputTokens,
            inputTokens: ipcStats.totalInputTokens,
            outputTokens: ipcStats.totalOutputTokens
        )
        
        return UsageStats(
            usage: usageData,
            failedRequests: ipcStats.failedRequests
        )
    }
    
    func reset() {
        cachedStats = nil
        lastError = nil
    }
}
