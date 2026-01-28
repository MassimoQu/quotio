//
//  RequestTracker.swift
//  Quotio - Request Tracking Service
//
//  Tracks API requests through the proxy for usage monitoring.
// Integrates with ModelUsageTracker to provide per-model analytics.
//
// This service is automatically used by ProxyBridge to track all proxied requests.
// No manual integration required - just ensure it's initialized.

import Foundation
import Combine

/// Tracks all API requests through the proxy for usage monitoring
@MainActor
@Observable
final class ProxyRequestTracker {
    
    // MARK: - Singleton
    
    static let shared = ProxyRequestTracker()
    
    // MARK: - Properties
    
    /// Whether tracking is currently active
    private(set) var isTracking = false
    
    /// Total requests tracked
    private(set) var totalRequests: Int = 0
    
    /// Requests in the current session
    private(set) var sessionRequests: Int = 0
    
    /// Session start time
    private(set) var sessionStartTime: Date = Date()
    
    /// Recent requests (last 100)
    private(set) var recentRequests: [TrackedRequest] = []
    
    /// Maximum recent requests to keep
    private let maxRecentRequests = 100
    
    /// Tracker for per-model usage
    let usageTracker = ModelUsageTracker.shared
    
    /// Publisher for UI updates
    var onRequestTracked: (() -> Void)?
    
    // MARK: - Lifecycle
    
    private init() {}
    
    // MARK: - Tracking Control
    
    /// Start tracking requests
    func start() {
        guard !isTracking else { return }
        isTracking = true
        sessionStartTime = Date()
        sessionRequests = 0
    }
    
    /// Stop tracking requests
    func stop() {
        isTracking = false
    }
    
    /// Reset all tracking data
    func reset() {
        totalRequests = 0
        sessionRequests = 0
        sessionStartTime = Date()
        recentRequests.removeAll()
        usageTracker.clearAllData()
        onRequestTracked?()
    }
    
    // MARK: - Request Tracking
    
    /// Track a new request
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - path: Request path
    ///   - provider: AI provider (openai, anthropic, etc.)
    ///   - model: Model identifier
    ///   - resolvedModel: Actual model used (after fallback/smart routing)
    ///   - resolvedProvider: Actual provider used
    ///   - statusCode: HTTP status code
    ///   - latencyMs: Request latency in milliseconds
    ///   - requestSize: Request body size in bytes
    ///   - responseSize: Response size in bytes
    ///   - tokens: Token usage (if available)
    func trackRequest(
        method: String,
        path: String,
        provider: String?,
        model: String?,
        resolvedModel: String?,
        resolvedProvider: String?,
        statusCode: Int?,
        latencyMs: Int,
        requestSize: Int,
        responseSize: Int,
        tokens: TokenUsage? = nil
    ) {
        guard isTracking else { return }
        
        let now = Date()
        let success = (statusCode ?? 0) >= 200 && (statusCode ?? 0) < 300
        
        // Create tracked request
        let request = TrackedRequest(
            timestamp: now,
            method: method,
            path: path,
            provider: resolvedProvider ?? provider ?? "unknown",
            model: resolvedModel ?? model ?? "unknown",
            statusCode: statusCode,
            latencyMs: latencyMs,
            requestSize: requestSize,
            responseSize: responseSize,
            success: success,
            tokens: tokens
        )
        
        // Update counters
        totalRequests += 1
        sessionRequests += 1
        
        // Update recent requests
        recentRequests.insert(request, at: 0)
        if recentRequests.count > maxRecentRequests {
            recentRequests.removeLast()
        }
        
        // Update model usage tracker
        if let resolvedModel = resolvedModel ?? model,
           let resolvedProvider = resolvedProvider ?? provider {
            usageTracker.recordRequest(
                model: resolvedModel,
                provider: resolvedProvider,
                inputTokens: tokens?.input ?? 0,
                outputTokens: tokens?.output ?? 0,
                latencyMs: latencyMs,
                success: success
            )
        }
        
        // Notify listeners
        onRequestTracked?()
    }
    
    // MARK: - Statistics
    
    /// Get session statistics
    func sessionStats() -> SessionStats {
        let duration = Date().timeIntervalSince(sessionStartTime)
        let requestsPerMinute = duration > 0 ? Double(sessionRequests) / (duration / 60) : 0
        
        let successfulRequests = recentRequests.filter { $0.success }.count
        let failedRequests = recentRequests.filter { !$0.success }.count
        
        return SessionStats(
            totalRequests: sessionRequests,
            duration: duration,
            requestsPerMinute: requestsPerMinute,
            successfulRequests: successfulRequests,
            failedRequests: failedRequests,
            successRate: sessionRequests > 0 ? Double(successfulRequests) / Double(sessionRequests) : 0
        )
    }
    
    /// Get provider breakdown
    func providerBreakdown() -> [String: Int] {
        Dictionary(grouping: recentRequests) { $0.provider }
            .mapValues { $0.count }
    }
    
    /// Get model breakdown
    func modelBreakdown() -> [(model: String, count: Int)] {
        Dictionary(grouping: recentRequests) { $0.model }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { (model: $0.key, count: $0.value) }
    }
    
    /// Get average latency by provider
    func averageLatencyByProvider() -> [String: Double] {
        var latencies: [String: [Int]] = [:]
        
        for request in recentRequests {
            latencies[request.provider, default: []].append(request.latencyMs)
        }
        
        return latencies.mapValues { values in
            Double(values.reduce(0, +)) / Double(values.count)
        }
    }
}

// MARK: - Tracked Request

/// A single tracked request
struct TrackedRequest: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let method: String
    let path: String
    let provider: String
    let model: String
    let statusCode: Int?
    let latencyMs: Int
    let requestSize: Int
    let responseSize: Int
    let success: Bool
    let tokens: TokenUsage?
    
    init(
        id: UUID = UUID(),
        timestamp: Date,
        method: String,
        path: String,
        provider: String,
        model: String,
        statusCode: Int?,
        latencyMs: Int,
        requestSize: Int,
        responseSize: Int,
        success: Bool,
        tokens: TokenUsage?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.method = method
        self.path = path
        self.provider = provider
        self.model = model
        self.statusCode = statusCode
        self.latencyMs = latencyMs
        self.requestSize = requestSize
        self.responseSize = responseSize
        self.success = success
        self.tokens = tokens
    }
}

/// Token usage information
struct TokenUsage: Sendable {
    let input: Int
    let output: Int
    
    var total: Int {
        input + output
    }
}

/// Session statistics
struct SessionStats {
    let totalRequests: Int
    let duration: TimeInterval
    let requestsPerMinute: Double
    let successfulRequests: Int
    let failedRequests: Int
    let successRate: Double
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}
