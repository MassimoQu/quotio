//
//  SmartRoutingModels.swift
//  Quotio - Smart Model Selection Based on Refresh Frequency
//
//  This file introduces intelligent model selection that considers
// account refresh frequency to optimize quota utilization.
//
// Key concept: Accounts that refresh more frequently (PRO accounts)
// should be used first, while accounts that refresh less frequently
// (FREE/COOLING accounts) should be preserved.
//
// Refresh Frequency Levels (highest to lowest priority):
//   - PRO/FREQUENT: Refreshes hourly or more (priority: 100)
//   - STANDARD: Refreshes daily (priority: 75)
//   - INFREQUENT: Refreshes weekly (priority: 50)
//   - LIMITED: Manual or rare refresh (priority: 25)
//   - COOLING: Recently used, in cooldown period (priority: 10)

import Foundation
import SwiftUI

// MARK: - Refresh Frequency Level

/// Represents how frequently an account refreshes its quota
/// Higher refresh frequency = higher priority for selection
enum RefreshFrequencyLevel: String, Codable, CaseIterable, Sendable {
    case pro         // Hourly or more frequent (PRO accounts)
    case standard    // Daily refresh
    case infrequent  // Weekly refresh
    case limited     // Manual/rare refresh
    case cooling     // Recently used, in cooldown
    
    var displayName: String {
        switch self {
        case .pro: return "PRO"
        case .standard: return "Standard"
        case .infrequent: return "Infrequent"
        case .limited: return "Limited"
        case .cooling: return "Cooling"
        }
    }
    
    var description: String {
        switch self {
        case .pro: return "Refreshes hourly or more (recommended for primary use)"
        case .standard: return "Refreshes daily (good for regular use)"
        case .infrequent: return "Refreshes weekly (sparingly used)"
        case .limited: return "Manual or rare refresh (use as last resort)"
        case .cooling: return "Recently used, currently cooling down"
        }
    }
    
    /// Priority value for sorting (higher = more preferred)
    var priorityValue: Int {
        switch self {
        case .pro: return 100
        case .standard: return 75
        case .infrequent: return 50
        case .limited: return 25
        case .cooling: return 10
        }
    }
    
    /// Color for UI display
    var color: Color {
        switch self {
        case .pro: return .green
        case .standard: return .blue
        case .infrequent: return .orange
        case .limited: return .gray
        case .cooling: return .red
        }
    }
    
    /// Icon for UI display
    var icon: String {
        switch self {
        case .pro: return "bolt.fill"
        case .standard: return "clock.fill"
        case .infrequent: return "calendar"
        case .limited: return "hand.raised"
        case .cooling: return "snowflake"
        }
    }
    
    /// Detect frequency level from provider and account metadata
    static func detect(from provider: AIProvider, accountKey: String, quotaData: ProviderQuotaData?) -> RefreshFrequencyLevel {
        // Check for known PRO account patterns
        let lowerKey = accountKey.lowercased()
        
        // PRO account indicators
        let proIndicators = ["pro", "premium", "paid", "plus", "team"]
        if proIndicators.contains(where: { lowerKey.contains($0) }) {
            return .pro
        }
        
        // Check quota data for refresh hints
        if let quota = quotaData, !quota.models.isEmpty {
            // If quota is consistently high, likely PRO
            let avgPercentage = quota.models.map(\\.percentage).reduce(0, +) / Double(quota.models.count)
            if avgPercentage > 80 {
                return .pro
            }
            if avgPercentage > 50 {
                return .standard
            }
        }
        
        // Default based on provider characteristics
        switch provider {
        case .antigravity:
            // Antigravity often has PRO accounts with daily refresh
            return .standard
        case .copilot:
            // Copilot typically has monthly limits
            return .standard
        case .claude:
            // Claude Code has varying limits
            return .standard
        case .codex:
            // Codex often has limited quotas
            return .infrequent
        case .glm:
            // GLM varies
            return .standard
        case .kiro:
            // Kiro can have various plans
            return .standard
        default:
            return .standard
        }
    }
}

// MARK: - Routing Strategy

/// Available routing strategies for model selection
enum RoutingStrategy: String, Codable, CaseIterable, Sendable {
    case roundRobin        // Cycle through entries evenly
    case fillFirst         // Fill one entry before moving to next
    case smartPriority     // Use smart priority based on refresh frequency (NEW)
    case loadBalanced      // Distribute based on current load
    case cacheFirst        // Prefer cached successful entries
    
    var displayName: String {
        switch self {
        case .roundRobin: return "Round Robin"
        case .fillFirst: return "Fill First"
        case .smartPriority: return "Smart Priority (Frequency-Aware)"
        case .loadBalanced: return "Load Balanced"
        case .cacheFirst: return "Cache First"
        }
    }
    
    var description: String {
        switch self {
        case .roundRobin:
            return "Distributes requests evenly across all entries in order"
        case .fillFirst:
            return "Uses the first available entry until exhausted, then moves to next"
        case .smartPriority:
            return "Prioritizes accounts with higher refresh frequency (PRO accounts first)"
        case .loadBalanced:
            return "Distributes based on current quota usage and performance"
        case .cacheFirst:
            return "Prefers previously successful entries for better hit rate"
        }
    }
    
    var isFrequencyAware: Bool {
        self == .smartPriority
    }
}

// MARK: - Smart Routing Entry

/// Enhanced fallback entry with smart routing metadata
struct SmartRoutingEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let provider: AIProvider
    let modelId: String
    var priority: Int                    // Manual priority (lower = higher preference)
    var refreshFrequency: RefreshFrequencyLevel  // Auto-detected refresh frequency
    var usageCount: Int                  // Number of requests routed to this entry
    var lastUsed: Date?                  // Last time this entry was used
    var successRate: Double              // Historical success rate (0.0 - 1.0)
    var lastSuccess: Date?               // Last successful request timestamp
    var isCooling: Bool                  // Whether entry is in cooldown
    var cooldownUntil: Date?             // Cooldown expiration
    
    init(
        id: UUID = UUID(),
        provider: AIProvider,
        modelId: String,
        priority: Int,
        refreshFrequency: RefreshFrequencyLevel = .standard,
        usageCount: Int = 0,
        lastUsed: Date? = nil,
        successRate: Double = 1.0,
        lastSuccess: Date? = nil,
        isCooling: Bool = false,
        cooldownUntil: Date? = nil
    ) {
        self.id = id
        self.provider = provider
        self.modelId = modelId
        self.priority = priority
        self.refreshFrequency = refreshFrequency
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.successRate = successRate
        self.lastSuccess = lastSuccess
        self.isCooling = isCooling
        self.cooldownUntil = cooldownUntil
    }
    
    /// Create from traditional FallbackEntry
    init(from entry: FallbackEntry, quotaData: ProviderQuotaData? = nil) {
        self.id = entry.id
        self.provider = entry.provider
        self.modelId = entry.modelId
        self.priority = entry.priority
        self.refreshFrequency = RefreshFrequencyLevel.detect(
            from: entry.provider,
            accountKey: entry.modelId,
            quotaData: quotaData
        )
        self.usageCount = 0
        self.lastUsed = nil
        self.successRate = 1.0
        self.lastSuccess = nil
        self.isCooling = false
        self.cooldownUntil = nil
    }
    
    /// Calculate effective priority score (higher = more preferred)
    /// Combines refresh frequency with manual priority and success rate
    var effectivePriorityScore: Double {
        guard !isCooling else { return 0 }
        
        let frequencyScore = Double(refreshFrequency.priorityValue) / 100.0
        
        // Manual priority: lower number = higher base priority
        // Convert to 0-1 scale where 1 = highest priority
        let manualPriorityScore = max(0, 1.0 - Double(priority - 1) / 10.0)
        
        // Success rate weight
        let successWeight = successRate
        
        // Combined score: frequency (40%) + manual priority (40%) + success rate (20%)
        return (frequencyScore * 0.4 + manualPriorityScore * 0.4 + successWeight * 0.2)
    }
    
    /// Check if entry is currently available for routing
    var isAvailable: Bool {
        guard !isCooling else { return false }
        
        if let cooldown = cooldownUntil, Date() < cooldown {
            return false
        }
        
        return true
    }
    
    /// Get cooldown status for UI
    var cooldownStatus: String? {
        guard isCooling, let until = cooldownUntil else { return nil }
        
        let remaining = until.timeIntervalSince(Date())
        if remaining <= 0 {
            return nil
        }
        
        if remaining < 60 {
            return "\(Int(remaining))s"
        } else if remaining < 3600 {
            return "\(Int(remaining / 60))m"
        } else {
            return "\(Int(remaining / 3600))h"
        }
    }
    
    /// Record a successful request
    func recordSuccess() -> SmartRoutingEntry {
        var copy = self
        copy.usageCount += 1
        copy.lastUsed = Date()
        copy.lastSuccess = Date()
        copy.successRate = min(1.0, Double(copy.usageCount) / Double(copy.usageCount + 1) * copy.successRate + 1.0 / Double(copy.usageCount + 1))
        return copy
    }
    
    /// Record a failed request (quota exceeded, etc.)
    func recordFailure() -> SmartRoutingEntry {
        var copy = self
        copy.usageCount += 1
        copy.lastUsed = Date()
        copy.successRate = max(0.0, Double(copy.usageCount - 1) / Double(copy.usageCount) * copy.successRate)
        return copy
    }
    
    /// Enter cooldown mode (e.g., after quota exhaustion)
    func enterCooldown(duration: TimeInterval = 300) -> SmartRoutingEntry {
        var copy = self
        copy.isCooling = true
        copy.cooldownUntil = Date().addingTimeInterval(duration)
        return copy
    }
    
    /// Exit cooldown mode
    func exitCooldown() -> SmartRoutingEntry {
        var copy = self
        copy.isCooling = false
        copy.cooldownUntil = nil
        return copy
    }
}

// MARK: - Smart Virtual Model

/// Enhanced virtual model with smart routing support
struct SmartVirtualModel: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var smartEntries: [SmartRoutingEntry]
    var strategy: RoutingStrategy
    var isEnabled: Bool
    
    /// Minimum time between uses of the same entry (for rate limiting)
    var rateLimitSeconds: Int
    
    /// Cooldown duration when an entry fails
    var cooldownDurationSeconds: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        smartEntries: [SmartRoutingEntry] = [],
        strategy: RoutingStrategy = .smartPriority,
        isEnabled: Bool = true,
        rateLimitSeconds: Int = 60,
        cooldownDurationSeconds: Int = 300
    ) {
        self.id = id
        self.name = name
        self.smartEntries = smartEntries
        self.strategy = strategy
        self.isEnabled = isEnabled
        self.rateLimitSeconds = rateLimitSeconds
        self.cooldownDurationSeconds = cooldownDurationSeconds
    }
    
    /// Create from traditional VirtualModel with smart routing metadata
    init(from virtualModel: VirtualModel, quotaData: [String: ProviderQuotaData]? = nil) {
        self.id = virtualModel.id
        self.name = virtualModel.name
        self.smartEntries = virtualModel.sortedEntries.map { entry in
            let key = "\(entry.provider.rawValue)-\(entry.modelId)"
            let providerQuota = quotaData?["\(entry.provider)"]
            return SmartRoutingEntry(from: entry, quotaData: providerQuota)
        }
        self.strategy = .smartPriority  // Default to smart priority for new models
        self.isEnabled = virtualModel.isEnabled
        self.rateLimitSeconds = 60
        self.cooldownDurationSeconds = 300
    }
    
    /// Get the next entry to use based on the configured strategy
    func selectNextEntry() -> SmartRoutingEntry? {
        guard isEnabled, !smartEntries.isEmpty else { return nil }
        
        let availableEntries = smartEntries.filter { $0.isAvailable }
        guard !availableEntries.isEmpty else { return nil }
        
        switch strategy {
        case .roundRobin:
            return selectRoundRobin(from: availableEntries)
        case .fillFirst:
            return selectFillFirst(from: availableEntries)
        case .smartPriority:
            return selectSmartPriority(from: availableEntries)
        case .loadBalanced:
            return selectLoadBalanced(from: availableEntries)
        case .cacheFirst:
            return selectCacheFirst(from: availableEntries)
        }
    }
    
    /// Round Robin: Cycle through entries in order
    private func selectRoundRobin(from entries: [SmartRoutingEntry]) -> SmartRoutingEntry? {
        // Return entry with lowest usage count (most balanced)
        return entries.min(by: { $0.usageCount < $1.usageCount })
    }
    
    /// Fill First: Use first available entry until exhausted
    private func selectFillFirst(from entries: [SmartRoutingEntry]) -> SmartRoutingEntry? {
        // Return first entry (highest priority)
        return entries.min(by: { $0.priority < $1.priority })
    }
    
    /// Smart Priority: Use entry with highest refresh frequency first
    private func selectSmartPriority(from entries: [SmartRoutingEntry]) -> SmartRoutingEntry? {
        // Sort by effective priority score (highest first)
        // This naturally puts PRO accounts first, then considers success rate and usage
        return entries.max(by: { $0.effectivePriorityScore < $1.effectivePriorityScore })
    }
    
    /// Load Balanced: Distribute based on current quota usage
    private func selectLoadBalanced(from entries: [SmartRoutingEntry]) -> SmartRoutingEntry? {
        // Prefer entries with lower usage count and better success rate
        return entries.min(by: {
            let score1 = Double($0.usageCount) * (1.0 - $0.successRate)
            let score2 = Double($1.usageCount) * (1.0 - $1.successRate)
            return score1 < score2
        })
    }
    
    /// Cache First: Prefer entries that were recently successful
    private func selectCacheFirst(from entries: [SmartRoutingEntry]) -> SmartRoutingEntry? {
        // Prefer entries that succeeded recently
        return entries.max(by: { ($0.lastSuccess ?? .distantPast) < ($1.lastSuccess ?? .distantPast) })
    }
    
    /// Update an entry after use
    mutating func updateEntry(_ entry: SmartRoutingEntry) {
        if let index = smartEntries.firstIndex(where: { $0.id == entry.id }) {
            smartEntries[index] = entry
        }
    }
    
    /// Record success for an entry
    mutating func recordSuccess(for entryId: UUID) {
        if let index = smartEntries.firstIndex(where: { $0.id == entryId }) {
            smartEntries[index] = smartEntries[index].recordSuccess()
        }
    }
    
    /// Record failure for an entry and enter cooldown if needed
    mutating func recordFailure(for entryId: UUID) {
        if let index = smartEntries.firstIndex(where: { $0.id == entryId }) {
            var entry = smartEntries[index].recordFailure()
            // Enter cooldown after consecutive failures
            if entry.usageCount > 3 && entry.successRate < 0.5 {
                entry = entry.enterCooldown(duration: TimeInterval(cooldownDurationSeconds))
            }
            smartEntries[index] = entry
        }
    }
}

// MARK: - Smart Routing Statistics

/// Statistics for smart routing performance
struct SmartRoutingStats: Codable, Sendable {
    var totalRequests: Int
    var successfulRequests: Int
    var failedRequests: Int
    var fallbackCount: Int
    var cooldownEntries: Int
    var entriesByFrequency: [RefreshFrequencyLevel: Int]
    
    init() {
        self.totalRequests = 0
        self.successfulRequests = 0
        self.failedRequests = 0
        self.fallbackCount = 0
        self.cooldownEntries = 0
        self.entriesByFrequency = [:]
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    var fallbackRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(fallbackCount) / Double(totalRequests)
    }
    
    mutating func recordRequest(success: Bool, requiredFallback: Bool) {
        totalRequests += 1
        if success {
            successfulRequests += 1
        } else {
            failedRequests += 1
        }
        if requiredFallback {
            fallbackCount += 1
        }
    }
}

// MARK: - Smart Routing Configuration

/// Global smart routing configuration
struct SmartRoutingConfiguration: Codable, Sendable {
    var isEnabled: Bool
    var virtualModels: [SmartVirtualModel]
    var defaultStrategy: RoutingStrategy
    var defaultCooldownSeconds: Int
    var defaultRateLimitSeconds: Int
    
    init(
        isEnabled: Bool = false,
        virtualModels: [SmartVirtualModel] = [],
        defaultStrategy: RoutingStrategy = .smartPriority,
        defaultCooldownSeconds: Int = 300,
        defaultRateLimitSeconds: Int = 60
    ) {
        self.isEnabled = isEnabled
        self.virtualModels = virtualModels
        self.defaultStrategy = defaultStrategy
        self.defaultCooldownSeconds = defaultCooldownSeconds
        self.defaultRateLimitSeconds = defaultRateLimitSeconds
    }
    
    /// Find a smart virtual model by name
    func findVirtualModel(name: String) -> SmartVirtualModel? {
        virtualModels.first { $0.name == name && $0.isEnabled }
    }
    
    /// Get all enabled virtual model names
    var enabledModelNames: [String] {
        virtualModels.filter(\\.isEnabled).map(\\.name)
    }
}
