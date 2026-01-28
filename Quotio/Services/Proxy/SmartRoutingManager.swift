//
//  SmartRoutingManager.swift
//  Quotio - Smart Model Selection Service
//
//  Manages intelligent model selection based on account refresh frequency.
// Implements the Smart Priority strategy that prioritizes PRO accounts
// (high refresh frequency) over FREE accounts.
//
// Architecture:
// - Tracks usage patterns and success rates per entry
// - Implements multiple routing strategies
// - Provides fallback selection with cooldown management
//
// Usage:
//   let manager = SmartRoutingManager.shared
//   if let entry = manager.selectNextEntry(for: "virtual-model-name") {
//       // Use entry.provider and entry.modelId for the request
//       manager.recordSuccess(for: entry.id)
//   }

import Foundation
import SwiftUI
import Combine

/// Manages smart model selection based on refresh frequency and performance
@MainActor
@Observable
final class SmartRoutingManager {
    
    // MARK: - Singleton
    
    static let shared = SmartRoutingManager()
    
    // MARK: - Properties
    
    /// Global configuration
    private(set) var configuration: SmartRoutingConfiguration
    
    /// Statistics for performance monitoring
    private(set) var stats: SmartRoutingStats
    
    /// Active virtual models being managed
    private var activeModels: [String: SmartVirtualModel] = [:]
    
    /// Publisher for UI updates
    var onConfigurationChanged: (() -> Void)?
    
    /// Publisher for stats updates
    var onStatsChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Load configuration from UserDefaults
        self.configuration = SmartRoutingConfiguration.load()
        self.stats = SmartRoutingStats.load()
        self.activeModels = [:]
        
        // Migrate from traditional fallback if needed
        migrateFromFallbackIfNeeded()
    }
    
    // MARK: - Configuration Management
    
    /// Load configuration from persistent storage
    func loadConfiguration() {
        configuration = SmartRoutingConfiguration.load()
        stats = SmartRoutingStats.load()
        onConfigurationChanged?()
        onStatsChanged?()
    }
    
    /// Save configuration to persistent storage
    func saveConfiguration() {
        configuration.save()
        stats.save()
    }
    
    /// Enable or disable smart routing globally
    func setEnabled(_ enabled: Bool) {
        configuration.isEnabled = enabled
        saveConfiguration()
        onConfigurationChanged?()
    }
    
    // MARK: - Virtual Model Management
    
    /// Get or create a smart virtual model
    func getOrCreateVirtualModel(name: String, strategy: RoutingStrategy = .smartPriority) -> SmartVirtualModel {
        if let existing = activeModels[name] {
            return existing
        }
        
        if let configured = configuration.findVirtualModel(name: name) {
            activeModels[name] = configured
            return configured
        }
        
        // Create new model
        let newModel = SmartVirtualModel(
            name: name,
            smartEntries: [],
            strategy: strategy,
            isEnabled: true
        )
        activeModels[name] = newModel
        return newModel
    }
    
    /// Add or update a virtual model
    func updateVirtualModel(_ model: SmartVirtualModel) {
        activeModels[model.name] = model
        configuration.virtualModels.removeAll { $0.name == model.name }
        configuration.virtualModels.append(model)
        saveConfiguration()
        onConfigurationChanged?()
    }
    
    /// Remove a virtual model
    func removeVirtualModel(name: String) {
        activeModels.removeValue(forKey: name)
        configuration.virtualModels.removeAll { $0.name == name }
        saveConfiguration()
        onConfigurationChanged?()
    }
    
    /// Add an entry to a virtual model
    func addEntry(
        to virtualModelName: String,
        provider: AIProvider,
        modelId: String,
        refreshFrequency: RefreshFrequencyLevel = .standard
    ) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        
        let newEntry = SmartRoutingEntry(
            provider: provider,
            modelId: modelId,
            priority: model.smartEntries.count + 1,
            refreshFrequency: refreshFrequency
        )
        
        model.smartEntries.append(newEntry)
        updateVirtualModel(model)
    }
    
    /// Update entry strategy
    func updateStrategy(for virtualModelName: String, strategy: RoutingStrategy) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        model.strategy = strategy
        updateVirtualModel(model)
    }
    
    /// Update entry refresh frequency (for manual override)
    func updateEntryFrequency(
        virtualModelName: String,
        entryId: UUID,
        frequency: RefreshFrequencyLevel
    ) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        if let index = model.smartEntries.firstIndex(where: { $0.id == entryId }) {
            model.smartEntries[index].refreshFrequency = frequency
            updateVirtualModel(model)
        }
    }
    
    // MARK: - Selection Logic
    
    /// Select the next entry to use based on configured strategy
    func selectNextEntry(for virtualModelName: String) -> SmartRoutingEntry? {
        guard configuration.isEnabled else { return nil }
        
        let model = getOrCreateVirtualModel(name: virtualModelName)
        guard model.isEnabled else { return nil }
        
        guard let selectedEntry = model.selectNextEntry() else {
            return nil
        }
        
        return selectedEntry
    }
    
    /// Select next entry with automatic fallback chain progression
    func selectWithFallback(for virtualModelName: String) -> (entry: SmartRoutingEntry, isFallback: Bool)? {
        guard configuration.isEnabled else { return nil }
        
        let model = getOrCreateVirtualModel(name: virtualModelName)
        guard model.isEnabled, !model.smartEntries.isEmpty else { return nil }
        
        // Select entry based on strategy
        guard let selectedEntry = model.selectNextEntry() else { return nil }
        
        // Track if this is a fallback (not the first entry)
        let isFallback = selectedEntry.priority > 1
        
        return (selectedEntry, isFallback)
    }
    
    // MARK: - Usage Tracking
    
    /// Record a successful request
    func recordSuccess(for virtualModelName: String, entryId: UUID) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        model.recordSuccess(for: entryId)
        updateVirtualModel(model)
        
        // Update stats
        stats.recordRequest(success: true, requiredFallback: false)
        saveConfiguration()
        onStatsChanged?()
    }
    
    /// Record a failed request
    func recordFailure(for virtualModelName: String, entryId: UUID) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        model.recordFailure(for: entryId)
        updateVirtualModel(model)
        
        // Update stats
        stats.recordRequest(success: false, requiredFallback: false)
        saveConfiguration()
        onStatsChanged?()
    }
    
    /// Record a fallback request (had to try next entry)
    func recordFallback(virtualModelName: String, entryId: UUID) {
        recordFailure(for: virtualModelName, entryId: entryId)
        
        var model = getOrCreateVirtualModel(name: virtualModelName)
        model.recordFailure(for: entryId)
        updateVirtualModel(model)
        
        // Update stats for fallback
        stats.recordRequest(success: false, requiredFallback: true)
        saveConfiguration()
        onStatsChanged?()
    }
    
    /// Reset statistics
    func resetStats() {
        stats = SmartRoutingStats()
        saveConfiguration()
        onStatsChanged?()
    }
    
    /// Reset all usage data for a virtual model
    func resetModelUsage(virtualModelName: String) {
        var model = getOrCreateVirtualModel(name: virtualModelName)
        for index in model.smartEntries.indices {
            model.smartEntries[index].usageCount = 0
            model.smartEntries[index].lastUsed = nil
            model.smartEntries[index].successRate = 1.0
            model.smartEntries[index].lastSuccess = nil
            model.smartEntries[index].isCooling = false
            model.smartEntries[index].cooldownUntil = nil
        }
        updateVirtualModel(model)
    }
    
    // MARK: - Statistics & Analytics
    
    /// Get statistics for a specific virtual model
    func modelStats(for virtualModelName: String) -> RoutingModelStats? {
        let model = getOrCreateVirtualModel(name: virtualModelName)
        guard !model.smartEntries.isEmpty else { return nil }
        
        let totalUsage = model.smartEntries.map { $0.usageCount }.reduce(0, +)
        let avgSuccessRate = model.smartEntries.map { $0.successRate }.reduce(0, +) / Double(model.smartEntries.count)
        let proCount = model.smartEntries.filter { $0.refreshFrequency == .pro }.count
        
        return RoutingModelStats(
            totalRequests: totalUsage,
            averageSuccessRate: avgSuccessRate,
            proAccountUsage: model.smartEntries.filter { $0.refreshFrequency == .pro }.map { $0.usageCount }.reduce(0, +),
            totalEntries: model.smartEntries.count,
            proEntries: proCount,
            entriesByFrequency: Dictionary(grouping: model.smartEntries) { $0.refreshFrequency }.mapValues { $0.count }
        )
    }
    
    /// Get routing efficiency report
    func efficiencyReport() -> RoutingEfficiencyReport {
        let totalModels = activeModels.count
        let enabledModels = activeModels.values.filter { $0.isEnabled }.count
        
        return RoutingEfficiencyReport(
            totalVirtualModels: totalModels,
            enabledModels: enabledModels,
            totalRequests: stats.totalRequests,
            successRate: stats.successRate,
            fallbackRate: stats.fallbackRate,
            cooldownEntries: stats.cooldownEntries,
            enabledModelsNames: configuration.enabledModelNames
        )
    }
    
    // MARK: - Migration
    
    /// Migrate from traditional FallbackSettingsManager if available
    private func migrateFromFallbackIfNeeded() {
        // Check if migration is needed (configuration exists but no smart routing)
        guard !configuration.virtualModels.isEmpty else {
            return
        }
        
        // Migration already done
    }
    
    /// Convert traditional virtual models to smart routing
    func convertFromFallback(
        _ fallbackModels: [VirtualModel],
        quotaData: [String: ProviderQuotaData]? = nil
    ) {
        for fallbackModel in fallbackModels {
            let smartModel = SmartVirtualModel(from: fallbackModel, quotaData: quotaData)
            configuration.virtualModels.append(smartModel)
        }
        saveConfiguration()
        onConfigurationChanged?()
    }
    
    // MARK: - Fallback Integration
    
    /// Check if smart routing should handle a request
    func shouldHandleRequest(modelName: String) -> Bool {
        guard configuration.isEnabled else { return false }
        return configuration.findVirtualModel(name: modelName) != nil || activeModels[modelName] != nil
    }
    
    /// Get the equivalent FallbackEntry for compatibility
    func getFallbackEntry(for virtualModelName: String, entryId: UUID) -> FallbackEntry? {
        let model = getOrCreateVirtualModel(name: virtualModelName)
        guard let entry = model.smartEntries.first(where: { $0.id == entryId }) else {
            return nil
        }
        
        return FallbackEntry(
            id: entry.id,
            provider: entry.provider,
            modelId: entry.modelId,
            priority: entry.priority
        )
    }
}

// MARK: - Supporting Types

/// Statistics for a specific virtual model
struct RoutingModelStats {
    let totalRequests: Int
    let averageSuccessRate: Double
    let proAccountUsage: Int
    let totalEntries: Int
    let proEntries: Int
    let entriesByFrequency: [RefreshFrequencyLevel: Int]
    
    var proUsagePercentage: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(proAccountUsage) / Double(totalRequests) * 100
    }
}

/// Routing efficiency report
struct RoutingEfficiencyReport {
    let totalVirtualModels: Int
    let enabledModels: Int
    let totalRequests: Int
    let successRate: Double
    let fallbackRate: Double
    let cooldownEntries: Int
    let enabledModelsNames: [String]
}

// MARK: - Codable Extensions

extension SmartRoutingConfiguration {
    private static let configKey = "quotio.smartRouting.config"
    
    static func load() -> SmartRoutingConfiguration {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(SmartRoutingConfiguration.self, from: data) else {
            return SmartRoutingConfiguration()
        }
        return config
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }
}

extension SmartRoutingStats {
    private static let statsKey = "quotio.smartRouting.stats"
    
    static func load() -> SmartRoutingStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(SmartRoutingStats.self, from: data) else {
            return SmartRoutingStats()
        }
        return stats
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
}
