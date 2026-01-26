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
    @StateObject private var usageTracker = ModelUsageTracker.shared
    @StateObject private var requestTracker = RequestTracker.shared
    
    @State private var selectedPeriod: UsageTimePeriod = .day
    @State private var selectedMetric: UsageMetricType = .requests
    @State private var selectedProvider: String? = nil
    @State private var isExporting = false
    @State private var showExportSuccess = false
    
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
                    usageTrendsSection
                    
                    // Provider breakdown
                    providerBreakdownSection
                    
                    // Model usage cards
                    modelUsageSection
                }
            }
            .padding()
        }
        .navigationTitle("usage.title".localized())
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $isExporting) {
            ExportUsageSheet(
                usageTracker: usageTracker,
                requestTracker: requestTracker,
                onDismiss: {
                    isExporting = false
                    showExportSuccess = true
                }
            )
        }
        .alert("usage.exportSuccess".localized(), isPresented: $showExportSuccess) {
            Button("action.ok".localized(), role: .cancel) {}
        } message: {
            Text("usage.exportSuccessMessage".localized())
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isExporting = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("usage.export".localized())
            .disabled(!isProxyRunning)
        }
        
        ToolbarItem(placement: .topBarLeading) {
            Button {
                // Refresh data
                usageTracker.refreshData()
                requestTracker.refreshData()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("usage.refresh".localized())
            .disabled(!isProxyRunning)
        }
    }
    
    // MARK: - Period Selector
    
    @ViewBuilder
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UsageTimePeriod.allCases, id: \.self) { period in
                    PeriodButton(
                        period: period,
                        isSelected: selectedPeriod == period,
                        action: {
                            selectedPeriod = period
                        }
                    )
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Overall Statistics
    
    @ViewBuilder
    private var overallStatsSection: some View {
        Section {
            OverallStatsGrid(
                usageTracker: usageTracker,
                requestTracker: requestTracker,
                period: selectedPeriod
            )
        } header: {
            Label("usage.overview".localized(), systemImage: "chart.bar")
        }
    }
    
    // MARK: - Usage Trends
    
    @ViewBuilder
    private var usageTrendsSection: some View {
        Section {
            UsageTrendsCard(
                usageTracker: usageTracker,
                period: selectedPeriod,
                metric: selectedMetric
            )
        } header: {
            HStack {
                Label("usage.trends".localized(), systemImage: "chart.line")
                Spacer()
                Picker("usage.metric".localized(), selection: $selectedMetric) {
                    Text("usage.requests".localized()).tag(UsageMetricType.requests)
                    Text("usage.tokens".localized()).tag(UsageMetricType.tokens)
                    Text("usage.cost".localized()).tag(UsageMetricType.cost)
                }
                .pickerStyle(.menu)
                .font(.caption)
            }
        }
    }
    
    // MARK: - Provider Breakdown
    
    @ViewBuilder
    private var providerBreakdownSection: some View {
        Section {
            ProviderUsageBreakdownView(
                usageTracker: usageTracker,
                period: selectedPeriod,
                selectedProvider: $selectedProvider
            )
        } header: {
            Label("usage.byProvider".localized(), systemImage: "square.grid.2x2")
        }
    }
    
    // MARK: - Model Usage Cards
    
    @ViewBuilder
    private var modelUsageSection: some View {
        Section {
            LazyVStack(spacing: 12) {
                ForEach(usageTracker.topModels(limit: 10, period: selectedPeriod)) { modelData in
                    ModelUsageCard(
                        modelData: modelData,
                        usageTracker: usageTracker,
                        period: selectedPeriod
                    )
                }
            }
        } header: {
            HStack {
                Label("usage.byModel".localized(), systemImage: "list.bullet")
                Spacer()
                Text("usage.topModels".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("usage.modelUsageFooter".localized())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Period Button

struct PeriodButton: View {
    let period: UsageTimePeriod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(period.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overall Statistics Grid

struct OverallStatsGrid: View {
    @ObservedObject var usageTracker: ModelUsageTracker
    @ObservedObject var requestTracker: RequestTracker
    let period: UsageTimePeriod
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "usage.totalRequests".localized(),
                value: "\(requestStats.totalRequests)",
                icon: "arrow.left.arrow.right",
                color: .blue
            )
            
            StatCard(
                title: "usage.totalTokens".localized(),
                value: formatNumber(totalTokens),
                icon: "textformat",
                color: .green
            )
            
            StatCard(
                title: "usage.totalCost".localized(),
                value: formatCurrency(totalCost),
                icon: "dollarsign.circle",
                color: .orange
            )
            
            StatCard(
                title: "usage.activeModels".localized(),
                value: "\(activeModels)",
                icon: "cube",
                color: .purple
            )
        }
    }
    
    private var requestStats: RequestTracker.SessionStats {
        requestTracker.sessionStats()
    }
    
    private var totalTokens: Int {
        usageTracker.totalTokens(period: period)
    }
    
    private var totalCost: Double {
        usageTracker.totalCost(period: period)
    }
    
    private var activeModels: Int {
        usageTracker.activeModels(period: period)
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Usage Trends Card

struct UsageTrendsCard: View {
    @ObservedObject var usageTracker: ModelUsageTracker
    let period: UsageTimePeriod
    let metric: UsageMetricType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chart
            if chartData.dataPoints.isEmpty {
                emptyChartState
            } else {
                chartView
            }
            
            // Legend
            if !chartData.dataPoints.isEmpty {
                HStack(spacing: 16) {
                    ForEach(Array(chartData.dataSets.keys.sorted().prefix(5)), id: \.self) { model in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(chartData.dataSets[model]?.color ?? .gray)
                                .frame(width: 8, height: 8)
                            Text(model)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var chartData: ChartDataResult {
        usageTracker.aggregateChartData(period: period, metric: metric)
    }
    
    @ViewBuilder
    private var chartView: some View {
        if period == .hour || period == .day {
            // Line chart for hourly/daily data
            Chart(chartData.dataPoints) { point in
                LineMark(
                    x: .value("Time", point.label),
                    y: .value(metric.displayName, point.value)
                )
                AreaMark(
                    x: .value("Time", point.label),
                    y: .value(metric.displayName, point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: 0...max(chartData.maxValue * 1.1, 1))
            .frame(height: 200)
        } else {
            // Bar chart for weekly/monthly data
            Chart(chartData.dataPoints) { point in
                BarMark(
                    x: .value("Period", point.label),
                    y: .value(metric.displayName, point.value)
                )
                .foregroundStyle(.blue.gradient)
            }
            .chartYScale(domain: 0...max(chartData.maxValue * 1.1, 1))
            .frame(height: 200)
        }
    }
    
    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("usage.noData".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Model Usage Card

struct ModelUsageCard: View {
    let modelData: ModelUsageData
    @ObservedObject var usageTracker: ModelUsageTracker
    let period: UsageTimePeriod
    
    @State private var isExpanded = false
    
    private var maxValue: Int {
        usageTracker.topModels(limit: 1, period: period).first?.totalRequests ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Provider icon
                    ProviderIcon(provider: modelData.provider, size: 32)
                        .opacity(0.8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modelData.model)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text(modelData.provider.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Stats
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(modelData.totalRequests)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text("usage.requests".localized())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            
            // Progress bar
            ProgressBar(
                value: Double(modelData.totalRequests),
                max: Double(max(maxValue, 1)),
                color: modelData.provider.color
            )
            
            // Expanded details
            if isExpanded {
                expandedDetails
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var expandedDetails: some View {
        VStack(spacing: 12) {
            Divider()
            
            // Detailed stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ExpandedStatRow(
                    title: "usage.tokensUsed".localized(),
                    value: "\(modelData.totalTokens)",
                    icon: "textformat"
                )
                
                ExpandedStatRow(
                    title: "usage.avgLatency".localized(),
                    value: formatLatency(modelData.avgLatencyMs),
                    icon: "clock"
                )
                
                ExpandedStatRow(
                    title: "usage.successRate".localized(),
                    value: String(format: "%.1f%%", modelData.successRate * 100),
                    icon: "checkmark.circle"
                )
                
                ExpandedStatRow(
                    title: "usage.estCost".localized(),
                    value: String(format: "$%.2f", modelData.estimatedCost),
                    icon: "dollarsign.circle"
                )
            }
            
            // Time breakdown
            if !modelData.usageByHour.isEmpty {
                hourlyBreakdown
            }
        }
    }
    
    private var hourlyBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("usage.hourlyBreakdown".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(modelData.usageByHour.keys.sorted().prefix(24)), id: \.self) { hour in
                        VStack(spacing: 2) {
                            Text("\(hour)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor)
                                .frame(
                                    width: 8,
                                    height: CGFloat(modelData.usageByHour[hour] ?? 0) * 2
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func formatLatency(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        } else {
            return String(format: "%.1fs", ms / 1000)
        }
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    let value: Double
    let max: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.gradient)
                    .frame(width: geometry.size.width * min(value / max, 1.0), height: 6)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Expanded Stat Row

struct ExpandedStatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Export Usage Sheet

struct ExportUsageSheet: View {
    @ObservedObject var usageTracker: ModelUsageTracker
    @ObservedObject var requestTracker: RequestTracker
    let onDismiss: () -> Void
    
    @State private var selectedFormat: ExportFormat = .json
    @State private var selectedPeriod: UsageTimePeriod = .day
    @State private var includeTokens = true
    @State private var includeCost = true
    @State private var isExporting = false
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("usage.exportFormat".localized()) {
                    Picker("usage.exportFormat".localized(), selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("usage.exportPeriod".localized()) {
                    Picker("usage.exportPeriod".localized(), selection: $selectedPeriod) {
                        ForEach(UsageTimePeriod.allCases, id: \.self) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                }
                
                Section("usage.exportInclude".localized()) {
                    Toggle("usage.includeTokens".localized(), isOn: $includeTokens)
                    Toggle("usage.includeCost".localized(), isOn: $includeCost)
                }
                
                Section {
                    Button {
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Label("usage.exportButton".localized(), systemImage: "square.and.arrow.up")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("usage.export".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel".localized()) {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private func performExport() {
        isExporting = true
        
        // Simulate export (in real implementation, would save to file)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isExporting = false
            onDismiss()
        }
    }
}

// MARK: - UsageTimePeriod Extension

extension UsageTimePeriod {
    var displayName: String {
        switch self {
        case .hour: return "usage.periodHour".localized()
        case .day: return "usage.periodDay".localized()
        case .week: return "usage.periodWeek".localized()
        case .month: return "usage.periodMonth".localized()
        case .all: return "usage.periodAll".localized()
        }
    }
}

// MARK: - UsageMetricType Extension

extension UsageMetricType {
    var displayName: String {
        switch self {
        case .requests: return "usage.metricRequests".localized()
        case .tokens: return "usage.metricTokens".localized()
        case .cost: return "usage.metricCost".localized()
        }
    }
}

#Preview {
    NavigationStack {
        UsageScreen()
            .environment(QuotaViewModel())
    }
}
