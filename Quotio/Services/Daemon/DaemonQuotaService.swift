//
//  DaemonQuotaService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonQuotaService {
    static let shared = DaemonQuotaService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var quotas: [AIProvider: [String: ProviderQuotaData]] = [:]
    private(set) var lastFetched: Date?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func fetchAllQuotas(forceRefresh: Bool = false) async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.fetchQuotas(forceRefresh: forceRefresh)
            quotas = convertQuotas(result.quotas)
            lastFetched = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func fetchQuotas(for provider: AIProvider, forceRefresh: Bool = false) async -> [String: ProviderQuotaData]? {
        do {
            try await ensureConnected()
            let result = try await apiClient.fetchQuotas(provider: provider.rawValue, forceRefresh: forceRefresh)
            
            let converted = convertQuotas(result.quotas)
            if let providerQuotas = converted[provider] {
                quotas[provider] = providerQuotas
                return providerQuotas
            }
        } catch {}
        
        return nil
    }
    
    func listCachedQuotas() async -> [AIProvider: [String: ProviderQuotaData]] {
        do {
            try await ensureConnected()
            let result = try await apiClient.listQuotas()
            return convertQuotas(result.quotas)
        } catch {
            return [:]
        }
    }
    
    private func convertQuotas(_ apiQuotas: [QuotaInfoAPI]) -> [AIProvider: [String: ProviderQuotaData]] {
        var result: [AIProvider: [String: ProviderQuotaData]] = [:]
        
        for apiQuota in apiQuotas {
            guard let provider = AIProvider(rawValue: apiQuota.provider) else { continue }
            
            let percentage = apiQuota.percent_used ?? 0.0
            let model = ModelQuota(
                name: "default",
                percentage: percentage,
                resetTime: "",
                used: apiQuota.used.map { Int($0) },
                limit: apiQuota.limit.map { Int($0) }
            )
            
            let lastUpdated: Date
            if let dateString = apiQuota.last_updated {
                lastUpdated = ISO8601DateFormatter().date(from: dateString) ?? Date()
            } else {
                lastUpdated = Date()
            }
            
            let quotaData = ProviderQuotaData(
                models: [model],
                lastUpdated: lastUpdated,
                isForbidden: false
            )
            
            let email = apiQuota.email ?? apiQuota.id
            if result[provider] == nil {
                result[provider] = [:]
            }
            result[provider]?[email] = quotaData
        }
        
        return result
    }
}
