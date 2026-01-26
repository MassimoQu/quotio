//
//  UsageChartView.swift
//  Quotio - Usage Visualization Charts
//
//  Provides Swift Charts-based visualizations for model usage data.
// Supports line charts, bar charts, and area charts with multiple metrics.
//
// Requirements: macOS 13.0+ for Swift Charts framework

import SwiftUI
import Charts

// MARK: - Usage Chart View

/// Main chart view for displaying usage data over time
struct UsageChartView: View {
    let chartData: ChartDataResult
    let title: String
    let subtitle: String?
    @State private var selectedPeriod: UsageTimePeriod = .day
    @State private var selectedMetric: UsageMetricType = .requests
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Controls
            HStack {
                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach([UsageTimePeriod.hour, .day, .week, .month], id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Metric picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach([UsageMetricType.requests, .totalTokens, .failures], id: \.self) { metric in
                        Label(metric.shortName, systemImage: metric.icon)
                            .tag(metric)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Chart
            if chartData.points.isEmpty {
                EmptyChartView(message: "No usage data for this period")
            } else {
                Chart(chartData.points) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(chartData.metric.displayName, point.value)
                    )
                    .foregroundStyle(chartData.metric.color.gradient)
                    .opacity(0.3)
                    
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(chartData.metric.displayName, point.value)
                    )
                    .foregroundStyle(chartData.metric.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value(chartData.metric.displayName, point.value)
                    )
                    .foregroundStyle(chartData.metric.color)
                    .symbolSize(10)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
            
            // Summary
            if !chartData.points.isEmpty {
                UsageSummaryView(summary: chartData.summary, metric: chartData.metric)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: selectedPeriod) { _, newPeriod in
            // Will be handled by parent with updated chart data
        }
    }
}

// MARK: - Empty Chart View

struct EmptyChartView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Usage Summary View

struct UsageSummaryView: View {
    let summary: ChartSummary
    let metric: UsageMetricType
    
    var body: some View {
        HStack(spacing: 24) {
            SummaryItem(
                label: "Total",
                value: formatValue(summary.total),
                metric: metric
            )
            
            SummaryItem(
                label: "Average",
                value: formatValue(summary.average),
                metric: metric,
                suffix: "/period"
            )
            
            SummaryItem(
                label: "Peak",
                value: formatValue(summary.max),
                metric: metric
            )
            
            Spacer()
            
            if let maxTime = summary.maxTimestamp {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Peak Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(maxTime, style: .time)
                        .font(.caption)
                }
            }
        }
        .font(.caption)
    }
    
    private func formatValue(_ value: Double) -> String {
        switch metric {
        case .requests, .failures:
            return "\(Int(value))"
        case .inputTokens, .outputTokens, .totalTokens:
            return formatCompactNumber(Int(value))
        case .cost:
            return String(format: "$%.2f", value)
        case .latency:
            return String(format: "%.0fms", value)
        }
    }
    
    private func formatCompactNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}

struct SummaryItem: View {
    let label: String
    let value: String
    let metric: UsageMetricType
    var suffix: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(metric.color)
                
                if let suffix = suffix {
                    Text(suffix)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Model Usage Card

/// Card view showing usage for a specific model with mini chart
struct ModelUsageCard: View {
    let usageData: ModelUsageData
    let chartData: ChartDataResult
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                ProviderIcon(provider: AIProvider(rawValue: usageData.provider) ?? .openai, size: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(usageData.modelId)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(usageData.provider)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(usageData.totalRequests)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("requests")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Mini chart
            if !chartData.points.isEmpty {
                Chart(chartData.points.prefix(20)) { point in
                    BarMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(UsageMetricType.requests.color.gradient)
                }
                .frame(height: 40)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
            
            // Expanded details
            if isExpanded {
                Divider()
                
                // Detailed stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatRow(icon: "text.insert", label: "Input Tokens", value: formatCompact(usageData.totalInputTokens), color: .green)
                    StatRow(icon: "text.bubble", label: "Output Tokens", value: formatCompact(usageData.totalOutputTokens), color: .purple)
                    StatRow(icon: "clock", label: "Avg Latency", value: String(format: "%.0fms", usageData.averageLatencyMs), color: .blue)
                    StatRow(icon: "checkmark.circle", label: "Success Rate", value: String(format: "%.0f%%", usageData.successRate * 100), color: .green)
                    StatRow(icon: "xmark.circle", label: "Failures", value: "\(usageData.totalFailures)", color: .red)
                    StatRow(icon: "calendar", label: "First Used", value: formatDate(usageData.firstUsed), color: .gray)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func formatCompact(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Provider Usage Breakdown

/// Chart showing usage breakdown by provider
struct ProviderUsageBreakdownView: View {
    let providerSummary: [String: ProviderUsageSummary]
    @State private var sortBy: SortOption = .requests
    
    enum SortOption: String, CaseIterable {
        case requests = "Requests"
        case tokens = "Tokens"
        case failures = "Failures"
    }
    
    var sortedProviders: [ProviderUsageSummary] {
        let providers = Array(providerSummary.values)
        switch sortBy {
        case .requests:
            return providers.sorted { $0.totalRequests > $1.totalRequests }
        case .tokens:
            return providers.sorted { $0.totalTokens > $1.totalTokens }
        case .failures:
            return providers.sorted { $0.totalFailures > $1.totalFailures }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Usage by Provider")
                    .font(.headline)
                
                Spacer()
                
                Picker("Sort by", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            
            // Bar chart
            if !sortedProviders.isEmpty {
                Chart(sortedProviders) { provider in
                    BarMark(
                        x: .value("Provider", provider.provider),
                        y: .value("Requests", provider.totalRequests)
                    )
                    .foregroundStyle(AIProvider(rawValue: provider.provider)?.color ?? .gray.gradient)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(sortedProviders.count * 40 + 50))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            } else {
                EmptyChartView(message: "No provider data")
            }
            
            // Legend/Summary
            if !sortedProviders.isEmpty {
                HStack(spacing: 16) {
                    ForEach(sortedProviders.prefix(3), id: \.provider) { provider in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AIProvider(rawValue: provider.provider)?.color ?? .gray)
                                .frame(width: 8, height: 8)
                            
                            Text(provider.provider)
                                .font(.caption)
                            
                            Text("(\(provider.modelCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(providerSummary.count) providers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Usage Trends Card

/// Card showing usage trends (up/down/stable)
struct UsageTrendsCard: View {
    let trends: UsageTrends
    let period: UsageTimePeriod
    
    var body: some View {
        HStack(spacing: 16) {
            // Trend indicator
            ZStack {
                Circle()
                    .fill(trends.trendDirection.color.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: trends.trendDirection.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(trends.trendDirection.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage Trend")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("vs previous \(period.displayName.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text(trends.trendDirection == .up ? "+" : "")
                    Text(String(format: "%.0f%%", abs(trends.changePercent)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(trends.trendDirection.color)
                }
                
                HStack(spacing: 8) {
                    Text("Current: \(formatCompactNumber(Int(trends.currentTotal)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Prev: \(formatCompactNumber(Int(trends.previousTotal)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatCompactNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}

// MARK: - Overall Stats Grid

/// Grid of overall usage statistics
struct OverallStatsGrid: View {
    let stats: OverallUsageStats
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            OverallStatItem(
                icon: "arrow.up.arrow.down",
                value: "\(stats.totalRequests)",
                label: "Total Requests",
                color: .blue
            )
            
            OverallStatItem(
                icon: "text.word.spacing",
                value: formatCompact(stats.totalTokens),
                label: "Total Tokens",
                color: .purple
            )
            
            OverallStatItem(
                icon: "checkmark.circle.fill",
                value: String(format: "%.0f%%", stats.successRate * 100),
                label: "Success Rate",
                color: .green
            )
            
            OverallStatItem(
                icon: "speedometer",
                value: String(format: "%.0fms", stats.averageLatencyMs),
                label: "Avg Latency",
                color: .orange
            )
        }
    }
    
    private func formatCompact(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}

struct OverallStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Multi-Model Comparison Chart

/// Chart comparing usage across multiple models
struct MultiModelComparisonChart: View {
    let models: [ModelUsageData]
    @State private var selectedMetric: UsageMetricType = .requests
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Model Comparison")
                    .font(.headline)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach([UsageMetricType.requests, .totalTokens, .failures], id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            if models.isEmpty {
                EmptyChartView(message: "No model data available")
            } else {
                Chart(models.prefix(8)) { model in
                    BarMark(
                        x: .value("Model", model.modelId),
                        y: .value(selectedMetric.displayName, metricValue(for: model, metric: selectedMetric))
                    )
                    .foregroundStyle((AIProvider(rawValue: model.provider) ?? .openai).color.gradient)
                    .cornerRadius(4)
                }
                .frame(height: CGFloat(models.count * 40 + 50))
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine()
                        AxisValueLabel(orientation: .verticalReversed)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func metricValue(for model: ModelUsageData, metric: UsageMetricType) -> Int {
        switch metric {
        case .requests:
            return model.totalRequests
        case .inputTokens:
            return model.totalInputTokens
        case .outputTokens:
            return model.totalOutputTokens
        case .totalTokens:
            return model.totalTokens
        case .failures:
            return model.totalFailures
        case .latency:
            return Int(model.averageLatencyMs)
        case .cost:
            return 0
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            OverallStatsGrid(stats: OverallUsageStats(
                totalRequests: 15420,
                totalTokens: 45000000,
                totalFailures: 234,
                uniqueModels: 5,
                uniqueProviders: 3,
                averageLatencyMs: 245,
                successRate: 0.985
            ))
            
            UsageTrendsCard(
                trends: UsageTrends(
                    currentTotal: 1250,
                    previousTotal: 980,
                    changePercent: 27.5,
                    trendDirection: .up
                ),
                period: .day
            )
            
            // Sample chart data
            let samplePoints = (0..<24).map { hour in
                UsageDataPoint(
                    timestamp: Calendar.current.date(byAdding: .hour, value: -hour, to: Date())!,
                    value: Double.random(in: 50...200)
                )
            }.reversed()
            
            UsageChartView(
                chartData: ChartDataResult(
                    period: .day,
                    metric: .requests,
                    points: samplePoints,
                    summary: ChartSummary(points: samplePoints)
                ),
                title: "API Requests Over Time",
                subtitle: "Last 24 hours"
            )
            
            MultiModelComparisonChart(models: [
                ModelUsageData(modelId: "gpt-4", provider: "openai", totalRequests: 5000, totalTokens: 15000000, totalFailures: 50),
                ModelUsageData(modelId: "claude-3-opus", provider: "anthropic", totalRequests: 3500, totalTokens: 12000000, totalFailures: 30),
                ModelUsageData(modelId: "gemini-pro", provider: "google", totalRequests: 2000, totalTokens: 8000000, totalFailures: 40)
            ])
        }
        .padding()
    }
    .background(Color(NSColor.textBackgroundColor))
}
