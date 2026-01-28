//
//  UsageScreen.swift
//  Quotio - Usage Analytics and Visualization
//
//  Fine-grained usage tracking with per-model time-series charts
//  and comprehensive analytics for monitoring API consumption.
//

import SwiftUI
import Charts

struct UsageScreen: View {
    @Environment(QuotaViewModel.self) private var viewModel
    @Bindable private var usageTracker = ModelUsageTracker.shared
    @Bindable private var requestTracker = ProxyRequestTracker.shared
    
    @State private var selectedPeriod: UsageTimePeriod = .day
    @State private var selectedMetric: UsageMetricType = .requests
    
    /// Proxy running status
    private var isProxyRunning: Bool {
        viewModel.proxyManager.proxyStatus.running
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period selector
                periodSelector
                
                if !isProxyRunning {
                    // Proxy not running state
                    proxyNotRunningState
                } else {
                    // Overall statistics
                    overallStatsSection
                    
                    // Usage trends chart
                    if !usageTracker.usageDataPoints(period: selectedPeriod).isEmpty {
                        usageTrendsSection
                    }
                    
                    // Provider breakdown
                    if usageTracker.providerUsage().count > 1 {
                        providerBreakdownSection
                    }
                    
                    // Model usage list
                    modelUsageSection
                }
            }
            .padding()
        }
        .navigationTitle("usage.title".localized())
        .refreshable {
            usageTracker.refreshData()
        }
    }
    
    // MARK: - Period Selector
    
    @ViewBuilder
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UsageTimePeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedPeriod == period ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedPeriod == period 
                                    ? Color.accentColor 
                                    : Color(NSColor.textBackgroundColor)
                            )
                            .foregroundColor(
                                selectedPeriod == period 
                                    ? .white 
                                    : .primary
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Proxy Not Running State
    
    @ViewBuilder
    private var proxyNotRunningState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("usage.proxyNotRunning".localized())
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("usage.proxyNotRunningDesc".localized())
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Overall Statistics
    
    @ViewBuilder
    private var overallStatsSection: some View {
        let stats = usageTracker.overallStats()
        
        VStack(alignment: .leading, spacing: 12) {
            Label("usage.overview".localized(), systemImage: "chart.bar")
                .font(.headline)
                .foregroundStyle(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatCard(
                    icon: "arrow.up.arrow.down",
                    value: formatNumber(stats.totalRequests),
                    label: "Total Requests",
                    color: .blue
                )
                
                StatCard(
                    icon: "text.word.spacing",
                    value: formatCompactNumber(stats.totalTokens),
                    label: "Total Tokens",
                    color: .green
                )
                
                StatCard(
                    icon: "exclamationmark.triangle",
                    value: formatNumber(stats.totalFailures),
                    label: "Failures",
                    color: .orange
                )
                
                StatCard(
                    icon: "checkmark.circle",
                    value: String(format: "%.1f%%", stats.successRate * 100),
                    label: "Success Rate",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Usage Trends
    
    @ViewBuilder
    private var usageTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("usage.trends".localized(), systemImage: "chart.line")
                    .font(.headline)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    Text("Requests").tag(UsageMetricType.requests)
                    Text("Tokens").tag(UsageMetricType.totalTokens)
                    Text("Failures").tag(UsageMetricType.failures)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            
            let points = usageTracker.chartData(period: selectedPeriod, metric: selectedMetric)
            
            if points.isEmpty {
                EmptyStateView(
                    icon: "chart.line.up.xyaxis",
                    message: "No data for this period"
                )
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.displayName, point.value)
                    )
                    .foregroundStyle(
                        selectedMetric.color.gradient.opacity(0.3)
                    )
                    
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.displayName, point.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.displayName, point.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Provider Breakdown
    
    @ViewBuilder
    private var providerBreakdownSection: some View {
        let providers = usageTracker.providerUsage().sorted { $0.totalRequests > $1.totalRequests }
        let maxRequests = providers.first?.totalRequests ?? 1
        
        VStack(alignment: .leading, spacing: 12) {
            Label("usage.byProvider".localized(), systemImage: "square.stack.3d.up")
                .font(.headline)
            
            if providers.isEmpty {
                EmptyStateView(
                    icon: "square.stack.3d.up",
                    message: "No provider data"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(providers) { provider in
                        ProviderRow(
                            provider: provider,
                            maxRequests: maxRequests,
                            metric: selectedMetric
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Model Usage
    
    @ViewBuilder
    private var modelUsageSection: some View {
        let topModels = usageTracker.topModels(by: selectedMetric, limit: 10, period: selectedPeriod)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("usage.byModel".localized(), systemImage: "list.bullet")
                    .font(.headline)
                
                Spacer()
                
                Text("\(topModels.count) models")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if topModels.isEmpty {
                EmptyStateView(
                    icon: "list.bullet",
                    message: "No model usage data"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(topModels.prefix(5)) { model in
                        ModelRow(
                            model: model,
                            metric: selectedMetric
                        )
                    }
                    
                    if topModels.count > 5 {
                        Button {
                            // TODO: Show all models
                        } label: {
                            Text("usage.viewAll".localized())
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct ProviderRow: View {
    let provider: ProviderUsageSummary
    let maxRequests: Int
    let metric: UsageMetricType
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(provider.provider)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(formatNumber(provider.totalRequests))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = CGFloat(provider.totalRequests) / CGFloat(maxRequests)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: width)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(width: width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct ModelRow: View {
    let model: ModelUsageData
    let metric: UsageMetricType
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.modelId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(model.provider)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(metricValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(metricLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
        )
    }
    
    private var metricValue: String {
        switch metric {
        case .requests:
            return "\(model.totalRequests)"
        case .totalTokens, .inputTokens, .outputTokens:
            let tokens = model.totalInputTokens + model.totalOutputTokens
            if tokens >= 1_000_000 {
                return String(format: "%.1fM", Double(tokens) / 1_000_000)
            } else if tokens >= 1_000 {
                return String(format: "%.1fK", Double(tokens) / 1_000)
            } else {
                return "\(tokens)"
            }
        case .failures:
            return "\(model.totalFailures)"
        default:
            return "\(model.totalRequests)"
        }
    }
    
    private var metricLabel: String {
        switch metric {
        case .requests:
            return "requests"
        case .totalTokens, .inputTokens, .outputTokens:
            return "tokens"
        case .failures:
            return "failures"
        default:
            return ""
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    NavigationStack {
        UsageScreen()
    }
    .environment(QuotaViewModel())
}
