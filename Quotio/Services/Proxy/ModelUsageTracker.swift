//
//  ModelUsageTracker.swift
//  Quotio - Per-Model Usage Tracking with Time-Series Visualization
//
//  Tracks API usage per model with time-series data for visualization.
// Provides detailed insights into which models are consuming quota
// and how usage patterns change over time.
//
// Key features:
// - Per-model request count tracking
// - Time-series data points for charts (hourly/daily/weekly views)
// - Token usage estimation
// - Success/failure rate tracking
// - Provider breakdown
//
// Usage:
//   ModelUsageTracker.shared.recordRequest(model: "gpt-4", provider: "openai", tokens: 1500)
//   let history = ModelUsageTracker.shared.history(for: "gpt-4", period: .day)
//   let chartData = ModelUsageTracker.shared.chartData(for: "gpt-4", period: .day)
//
// Chart data can be visualized with Swift Charts:
//   Chart(chartData.points) { point in
//       LineMark(x: .value("Time", point.timestamp), y: .value("Requests", point.value))
//   }

import Foundation
import SwiftUI
import Combine

// MARK: - Time Period

/// Time period for usage history and charts
enum UsageTimePeriod: String, CaseIterable, Codable, Sendable {
    case hour   // Last hour, 1-minute resolution
    case day    // Last 24 hours, 1-hour resolution
    case week   // Last 7 days, 1-day resolution
    case month  // Last 30 days, 1-day resolution
    case all    // All time, aggregated by day
    
    var displayName: String {
        switch self {
        case .hour: return "Last Hour"
        case .day: return "Last 24 Hours"
        case .week: return "Last 7 Days"
        case .month: return "Last 30 Days"
        case .all: return "All Time"
        }
    }
    
    var description: String {
        switch self {
        case .hour: return "1-minute intervals"
        case .day: return "Hourly intervals"
        case .week: return "Daily intervals"
        case .month: return "Daily intervals"
        case .all: return "Aggregated daily"
        }
    }
    
    /// Duration in seconds
    var duration: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        case .all: return 31536000  // 1 year default
        }
    }
    
    /// Resolution interval in seconds
    var resolution: TimeInterval {
        switch self {
        case .hour: return 60
        case .day: return 3600
        case .week: return 86400
        case .month: let _ = 86400
            return 86400
        case .all: return 86400
        }
    }
}

// MARK: - Usage Data Point

/// A single data point for usage charts
struct UsageDataPoint: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let value: Double
    let label: String  // Formatted label for x-axis
    
    init(id: UUID = UUID(), timestamp: Date, value: Double, label: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.value = value
        self.label = label.isEmpty ? Self.formatLabel(for: timestamp, period: .day) : label
    }
    
    static func formatLabel(for date: Date, period: UsageTimePeriod) -> String {
        let formatter = DateFormatter()
        
        switch period {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week, .month:
            formatter.dateFormat = "MM/dd"
        case .all:
            formatter.dateFormat = "MM/dd"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Usage Metric Type

/// Type of metric being tracked
enum UsageMetricType: String, CaseIterable, Codable, Sendable {
    case requests      // Number of requests
    case inputTokens   // Input tokens consumed
    case outputTokens  // Output tokens consumed
    case totalTokens   // Total tokens (input + output)
    case cost          // Estimated cost (if available)
    case failures      // Number of failed requests
    case latency       // Average latency in ms
    
    var displayName: String {
        switch self {
        case .requests: return "Requests"
        case .inputTokens: return "Input Tokens"
        case .outputTokens: return "Output Tokens"
        case .totalTokens: return "Total Tokens"
        case .cost: return "Cost"
        case .failures: return "Failures"
        case .latency: return "Latency"
        }
    }
    
    var shortName: String {
        switch self {
        case .requests: return "Req"
        case .inputTokens: return "In"
        case .outputTokens: return "Out"
        case .totalTokens: return "Total"
        case .cost: return "$"
        case .failures: return "Err"
        case .latency: return "ms"
        }
    }
    
    var icon: String {
        switch self {
        case .requests: return "arrow.up.arrow.down"
        case .inputTokens: return "text.insert"
        case .outputTokens: return "text.bubble"
        case .totalTokens: return "sum"
        case .cost: return "dollarsign.circle"
        case .failures: return "xmark.circle"
        case .latency: return "speedometer"
        }
    }
    
    var color: Color {
        switch self {
        case .requests: return .blue
        case .inputTokens: return .green
        case .outputTokens: return .purple
        case .totalTokens: return .orange
        case .cost: return .green
        case .failures: return .red
        case .latency: return .gray
        }
    }
}

// MARK: - Model Usage Data

/// Usage data for a single model
struct ModelUsageData: Codable, Identifiable, Sendable {
    let id: UUID
    let modelId: String
    let provider: String
    var totalRequests: Int
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalFailures: Int
    var totalLatencyMs: Int
    var firstUsed: Date
    var lastUsed: Date
    var history: [UsageDataPoint]  // Time-series data
    
    init(
        id: UUID = UUID(),
        modelId: String,
        provider: String,
        totalRequests: Int = 0,
        totalInputTokens: Int = 0,
        totalOutputTokens: Int = 0,
        totalFailures: Int = 0,
        totalLatencyMs: Int = 0,
        firstUsed: Date = Date(),
        lastUsed: Date = Date(),
        history: [UsageDataPoint] = []
    ) {
        self.id = id
        self.modelId = modelId
        self.provider = provider
        self.totalRequests = totalRequests
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = outputTokens
        self.totalFailures = totalFailures
        self.totalLatencyMs = totalLatencyMs
        self.firstUsed = firstUsed
        self.lastUsed = lastUsed
        self.history = history
    }
    
    var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - totalFailures) / Double(totalRequests)
    }
    
    var averageLatencyMs: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalLatencyMs) / Double(totalRequests)
    }
    
    /// Get chart data for a specific period and metric
    func chartData(period: UsageTimePeriod, metric: UsageMetricType = .requests) -> [UsageDataPoint] {
        let cutoff = Date().addingTimeInterval(-period.duration)
        let recentHistory = history.filter { $0.timestamp >= cutoff }
        
        // Aggregate to period resolution
        var aggregated: [Date: Double] = [:]
        
        for point in recentHistory {
            let bucket = point.timestamp.timeIntervalSince1970 / period.resolution
            let bucketDate = Date(timeIntervalSince1970: bucket * period.resolution)
            let label = UsageDataPoint.formatLabel(for: bucketDate, period: period)
            
            let existing = aggregated[bucketDate] ?? 0
            switch metric {
            case .requests:
                aggregated[bucketDate] = existing + point.value
            case .inputTokens, .outputTokens, .totalTokens:
                aggregated[bucketDate] = existing + point.value
            case .failures:
                aggregated[bucketDate] = existing + point.value
            case .cost:
                aggregated[bucketDate] = existing + point.value
            case .latency:
                // Average latency - need to track separately
                aggregated[bucketDate] = existing + point.value
            }
        }
        
        // Convert to sorted data points
        return aggregated
            .map { UsageDataPoint(timestamp: $0.key, value: $0.value) }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Chart Data Result

/// Aggregated chart data for visualization
struct ChartDataResult: Identifiable, Sendable {
    let id: String
    let period: UsageTimePeriod
    let metric: UsageMetricType
    let points: [UsageDataPoint]
    let summary: ChartSummary
    
    init(period: UsageTimePeriod, metric: UsageMetricType, points: [UsageDataPoint], summary: ChartSummary) {
        self.id = "\(period.rawValue)-\(metric.rawValue)"
        self.period = period
        self.metric = metric
        self.points = points
        self.summary = summary
    }
}

/// Summary statistics for chart data
struct ChartSummary: Sendable {
    let total: Double
    let average: Double
    let max: Double
    let min: Double
    let maxTimestamp: Date?
    let minTimestamp: Date?
    
    init(points: [UsageDataPoint]) {
        guard !points.isEmpty else {
            self.total = 0
            self.average = 0
            self.max = 0
            self.min = 0
            self.maxTimestamp = nil
            self.minTimestamp = nil
            return
        }
        
        let values = points.map($0.value)
        self.total = values.reduce(0, +)
        self.average = total / Double(values.count)
        self.max = values.max() ?? 0
        self.min = values.min() ?? 0
        self.maxTimestamp = points.first { $0.value == max }?.timestamp
        self.minTimestamp = points.first { $0.value == min }?.timestamp
    }
}

// MARK: - Model Usage Tracker

/// Tracks API usage per model with time-series data for visualization
@MainActor
@Observable
final class ModelUsageTracker {
    
    // MARK: - Singleton
    
    static let shared = ModelUsageTracker()
    
    // MARK: - Properties
    
    /// Per-model usage data keyed by "provider-model"
    private(set) var modelUsageData: [String: ModelUsageData] = [:]
    
    /// All unique providers being tracked
    private(set) var trackedProviders: Set<String> = []
    
    /// All unique models being tracked
    private(set) var trackedModels: Set<String> = []
    
    /// Maximum history points to keep per model
    private let maxHistoryPoints = 1000
    
    /// History resolution in seconds
    private let historyResolution: TimeInterval = 300  // 5 minutes
    
    /// Publisher for UI updates
    var onDataChanged: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        loadFromStorage()
    }
    
    // MARK: - Recording
    
    /// Record a new request
    /// - Parameters:
    ///   - model: The model ID (e.g., "gpt-4", "claude-3-opus")
    ///   - provider: The provider (e.g., "openai", "anthropic")
    ///   - inputTokens: Number of input tokens (optional)
    ///   - outputTokens: Number of output tokens (optional)
    ///   - latencyMs: Request latency in milliseconds
    ///   - success: Whether the request succeeded
    func recordRequest(
        model: String,
        provider: String,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        latencyMs: Int = 0,
        success: Bool = true
    ) {
        let key = "\(provider)-\(model)"
        let now = Date()
        
        // Get or create usage data
        var usageData: ModelUsageData
        if let existing = modelUsageData[key] {
            usageData = existing
        } else {
            usageData = ModelUsageData(
                modelId: model,
                provider: provider,
                firstUsed: now,
                lastUsed: now
            )
            
            // Track new provider and model
            trackedProviders.insert(provider)
            trackedModels.insert(model)
        }
        
        // Update totals
        usageData.totalRequests += 1
        usageData.totalInputTokens += inputTokens
        usageData.totalOutputTokens += outputTokens
        usageData.totalLatencyMs += latencyMs
        if !success {
            usageData.totalFailures += 1
        }
        usageData.lastUsed = now
        
        // Add history point
        let historyPoint = createHistoryPoint(
            model: model,
            provider: provider,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            success: success
        )
        
        // Keep history manageable
        if usageData.history.count >= maxHistoryPoints {
            // Sample down - keep every Nth point
            let stride = 2
            usageData.history = Array(usageData.history.enumerated()
                .filter { $0.offset % stride == 0 || $0.offset == usageData.history.count - 1 }
                .map(\\.element))
            usageData.history.append(historyPoint)
        } else {
            usageData.history.append(historyPoint)
        }
        
        modelUsageData[key] = usageData
        saveToStorage()
        onDataChanged?()
    }
    
    /// Create a history data point
    private func createHistoryPoint(
        model: String,
        provider: String,
        inputTokens: Int,
        outputTokens: Int,
        success: Bool
    ) -> UsageDataPoint {
        let now = Date()
        return UsageDataPoint(
            timestamp: now,
            value: 1,  // One request
            label: Self.formatLabel(for: now, period: .day)
        )
    }
    
    // MARK: - Querying
    
    /// Get usage data for a specific model
    func usageData(for model: String, provider: String) -> ModelUsageData? {
        modelUsageData["\(provider)-\(model)"]
    }
    
    /// Get chart data for a specific model
    func chartData(
        for model: String,
        provider: String,
        period: UsageTimePeriod = .day,
        metric: UsageMetricType = .requests
    ) -> ChartDataResult {
        let key = "\(provider)-\(model)"
        
        guard let usageData = modelUsageData[key] else {
            return ChartDataResult(
                period: period,
                metric: metric,
                points: [],
                summary: ChartSummary(points: [])
            )
        }
        
        let points = usageData.chartData(period: period, metric: metric)
        let summary = ChartSummary(points: points)
        
        return ChartDataResult(
            period: period,
            metric: metric,
            points: points,
            summary: summary
        )
    }
    
    /// Get all usage data sorted by total requests
    func sortedUsageData(limit: Int = 10) -> [ModelUsageData] {
        Array(modelUsageData.values
            .sorted { $0.totalRequests > $1.totalRequests }
            .prefix(limit))
    }
    
    /// Get usage breakdown by provider
    func usageByProvider() -> [String: ProviderUsageSummary] {
        var summary: [String: ProviderUsageSummary] = [:]
        
        for (key, data) in modelUsageData {
            if let existing = summary[data.provider] {
                summary[data.provider] = ProviderUsageSummary(
                    provider: data.provider,
                    totalRequests: existing.totalRequests + data.totalRequests,
                    totalTokens: existing.totalTokens + data.totalTokens,
                    totalFailures: existing.totalFailures + data.totalFailures,
                    modelCount: existing.modelCount + 1
                )
            } else {
                summary[data.provider] = ProviderUsageSummary(
                    provider: data.provider,
                    totalRequests: data.totalRequests,
                    totalTokens: data.totalTokens,
                    totalFailures: data.totalFailures,
                    modelCount: 1
                )
            }
        }
        
        return summary
    }
    
    /// Get top models by usage
    func topModels(by metric: UsageMetricType = .requests, limit: Int = 5) -> [ModelUsageData] {
        let sorted: [ModelUsageData]
        
        switch metric {
        case .requests:
            sorted = modelUsageData.values.sorted { $0.totalRequests > $1.totalRequests }
        case .inputTokens:
            sorted = modelUsageData.values.sorted { $0.totalInputTokens > $1.totalInputTokens }
        case .outputTokens:
            sorted = modelUsageData.values.sorted { $0.totalOutputTokens > $1.totalOutputTokens }
        case .totalTokens:
            sorted = modelUsageData.values.sorted { $0.totalTokens > $1.totalTokens }
        case .failures:
            sorted = modelUsageData.values.sorted { $0.totalFailures > $1.totalFailures }
        case .latency:
            sorted = modelUsageData.values.sorted { $0.averageLatencyMs > $1.averageLatencyMs }
        case .cost:
            // Cost not tracked
            sorted = modelUsageData.values.sorted { $0.totalRequests > $1.totalRequests }
        }
        
        return Array(sorted.prefix(limit))
    }
    
    /// Get combined chart data for all models (aggregate)
    func aggregateChartData(
        period: UsageTimePeriod = .day,
        metric: UsageMetricType = .requests
    ) -> ChartDataResult {
        let allPoints = modelUsageData.values.flatMap { $0.chartData(period: period, metric: metric) }
        
        // Aggregate by timestamp
        var aggregated: [Date: Double] = [:]
        
        for point in allPoints {
            let bucket = point.timestamp.timeIntervalSince1970 / period.resolution
            let bucketDate = Date(timeIntervalSince1970: bucket * period.resolution)
            
            let existing = aggregated[bucketDate] ?? 0
            aggregated[bucketDate] = existing + point.value
        }
        
        let points = aggregated
            .map { UsageDataPoint(timestamp: $0.key, value: $0.value) }
            .sorted { $0.timestamp < $1.timestamp }
        
        let summary = ChartSummary(points: points)
        
        return ChartDataResult(
            period: period,
            metric: metric,
            points: points,
            summary: summary
        )
    }
    
    // MARK: - Statistics
    
    /// Get overall statistics
    func overallStats() -> OverallUsageStats {
        let allData = modelUsageData.values
        
        let totalRequests = allData.map(\\.totalRequests).reduce(0, +)
        let totalTokens = allData.map(\\.totalTokens).reduce(0, +)
        let totalFailures = allData.map(\\.totalFailures).reduce(0, +)
        let totalLatency = allData.map(\\.totalLatencyMs).reduce(0, +)
        
        return OverallUsageStats(
            totalRequests: totalRequests,
            totalTokens: totalTokens,
            totalFailures: totalFailures,
            uniqueModels: trackedModels.count,
            uniqueProviders: trackedProviders.count,
            averageLatencyMs: totalRequests > 0 ? Double(totalLatency) / Double(totalRequests) : 0,
            successRate: totalRequests > 0 ? Double(totalRequests - totalFailures) / Double(totalRequests) : 0
        )
    }
    
    /// Get usage trends (compare current period to previous)
    func usageTrends(period: UsageTimePeriod = .day) -> UsageTrends {
        let current = aggregateChartData(period: period)
        
        // Calculate previous period
        let previousPeriodStart = Date().addingTimeInterval(-period.duration * 2)
        let previousPeriodEnd = Date().addingTimeInterval(-period.duration)
        
        let previousPoints = modelUsageData.values
            .flatMap(\\.history)
            .filter { $0.timestamp >= previousPeriodStart && $0.timestamp < previousPeriodEnd }
        
        let previousTotal = previousPoints.map($0.value).reduce(0, +)
        
        let changePercent: Double
        if previousTotal > 0 {
            changePercent = (current.summary.total - previousTotal) / previousTotal * 100
        } else {
            changePercent = current.summary.total > 0 ? 100 : 0
        }
        
        return UsageTrends(
            currentTotal: current.summary.total,
            previousTotal: previousTotal,
            changePercent: changePercent,
            trendDirection: changePercent > 0 ? .up : (changePercent < 0 ? .down : .stable)
        )
    }
    
    // MARK: - Storage
    
    /// Save to persistent storage
    func saveToStorage() {
        guard let data = try? JSONEncoder().encode(modelUsageData) else { return }
        UserDefaults.standard.set(data, forKey: "quotio.modelUsageHistory")
    }
    
    /// Load from persistent storage
    func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: "quotio.modelUsageHistory"),
              let loaded = try? JSONDecoder().decode([String: ModelUsageData].self, from: data) else {
            return
        }
        
        modelUsageData = loaded
        
        // Rebuild tracked sets
        trackedProviders = Set(modelUsageData.values.map(\\.provider))
        trackedModels = Set(modelUsageData.values.map(\\.modelId))
    }
    
    /// Clear all usage data
    func clearAllData() {
        modelUsageData.removeAll()
        trackedProviders.removeAll()
        trackedModels.removeAll()
        UserDefaults.standard.removeObject(forKey: "quotio.modelUsageHistory")
        onDataChanged?()
    }
    
    /// Clear data for a specific model
    func clearData(for model: String, provider: String) {
        let key = "\(provider)-\(model)"
        modelUsageData.removeValue(forKey: key)
        
        // Update tracked sets
        if !modelUsageData.values.contains(where: { $0.provider == provider }) {
            trackedProviders.remove(provider)
        }
        if !modelUsageData.values.contains(where: { $0.modelId == model }) {
            trackedModels.remove(model)
        }
        
        saveToStorage()
        onDataChanged?()
    }
    
    // MARK: - Helpers
    
    private static func formatLabel(for date: Date, period: UsageTimePeriod) -> String {
        let formatter = DateFormatter()
        
        switch period {
        case .hour:
            formatter.dateFormat = "HH:mm"
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week, .month:
            formatter.dateFormat = "MM/dd"
        case .all:
            formatter.dateFormat = "MM/dd"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

/// Summary of usage for a provider
struct ProviderUsageSummary: Sendable {
    let provider: String
    let totalRequests: Int
    let totalTokens: Int
    let totalFailures: Int
    let modelCount: Int
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - totalFailures) / Double(totalRequests)
    }
}

/// Overall usage statistics
struct OverallUsageStats: Sendable {
    let totalRequests: Int
    let totalTokens: Int
    let totalFailures: Int
    let uniqueModels: Int
    let uniqueProviders: Int
    let averageLatencyMs: Double
    let successRate: Double
}

/// Usage trends comparison
struct UsageTrends: Sendable {
    let currentTotal: Double
    let previousTotal: Double
    let changePercent: Double
    let trendDirection: TrendDirection
    
    enum TrendDirection: String, Sendable {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
    }
}
