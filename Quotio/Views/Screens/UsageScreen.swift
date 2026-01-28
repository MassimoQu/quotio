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
    @StateObject private var requestTracker = ProxyRequestTracker.shared
    
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

// MARK: - Model Usage Card

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
