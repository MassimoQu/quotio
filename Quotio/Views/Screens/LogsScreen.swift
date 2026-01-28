//
//  LogsScreen.swift
//  Quotio - Request and Proxy Logs
//
//  Monitoring interface for tracking proxy requests and system logs.
//

import SwiftUI

struct LogsScreen: View {
    @Environment(QuotaViewModel.self) private var viewModel
    @Environment(LogsViewModel.self) private var logsViewModel
    @Bindable private var requestTracker = ProxyRequestTracker.shared
    
    @State private var selectedTab: LogsTab = .requests
    @State private var searchText = ""
    @State private var requestFilterProvider: String? = nil
    @State private var selectedRequest: TrackedRequest?
    
    enum LogsTab: String, CaseIterable {
        case requests = "requests"
        case proxyLogs = "proxyLogs"
        
        var title: String {
            switch self {
            case .requests: return "logs.tab.requests".localizedStatic()
            case .proxyLogs: return "logs.tab.proxyLogs".localizedStatic()
            }
        }
        
        var icon: String {
            switch self {
            case .requests: return "arrow.up.arrow.down"
            case .proxyLogs: return "doc.text"
            }
        }
    }
    
    var body: some View {
        Group {
            if !viewModel.proxyManager.proxyStatus.running {
                ProxyRequiredView(
                    description: "logs.startProxy".localized()
                ) {
                    await viewModel.startProxy()
                }
            } else {
                VStack(spacing: 0) {
                    // Tab Picker
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(LogsTab.allCases, id: \.self) { tab in
                            Label(tab.title, systemImage: tab.icon)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    Divider()
                    
                    // Tab Content
                    switch selectedTab {
                    case .requests:
                        requestHistoryView
                    case .proxyLogs:
                        proxyLogsView
                    }
                }
            }
        }
        .navigationTitle("nav.logs".localized())
        .searchable(text: $searchText, prompt: searchPrompt)
        .toolbar {
            toolbarContent
        }
        .task {
            // Configure LogsViewModel with proxy connection when screen appears
            if !logsViewModel.isConfigured {
                logsViewModel.configure(
                    baseURL: viewModel.proxyManager.managementURL,
                    authKey: viewModel.proxyManager.managementKey
                )
            }
            
            while !Task.isCancelled {
                if selectedTab == .proxyLogs {
                    await logsViewModel.refreshLogs()
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        .sheet(item: $selectedRequest) { request in
            RequestDetailSheet(request: request)
        }
    }
    
    private var searchPrompt: String {
        switch selectedTab {
        case .requests:
            return "logs.searchRequests".localized()
        case .proxyLogs:
            return "logs.searchLogs".localized()
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                // Toggle auto-scroll
                Button {
                    // Auto-scroll toggle
                } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .help("logs.autoScroll".localized())
                
                // Clear logs
                Button(role: .destructive) {
                    // Clear recent requests
                    requestTracker.clearHistory()
                } label: {
                    Image(systemName: "trash")
                }
                .help("logs.clear".localized())
            }
        }
    }
    
    // MARK: - Request History View
    
    private var requestHistoryView: some View {
        let requests = filteredRequests
        
        Group {
            if requests.isEmpty {
                ContentUnavailableView {
                    Label("logs.noRequests".localized(), systemImage: "arrow.up.arrow.down")
                } description: {
                    Text("logs.requestsWillAppear".localized())
                }
            } else {
                VStack(spacing: 0) {
                    // Stats Header
                    requestStatsHeader
                    
                    Divider()
                    
                    // Request List
                    List(requests) { request in
                        RequestRow(request: request)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRequest = request
                            }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
    
    private var requestStatsHeader: some View {
        let stats = calculateStats()
        
        return HStack(spacing: 20) {
            StatItem(
                title: "logs.stats.totalRequests".localized(),
                value: "\(stats.totalRequests)",
                icon: "arrow.up.arrow.down"
            )
            
            StatItem(
                title: "logs.stats.successRate".localized(),
                value: String(format: "%.0f%%", stats.successRate * 100),
                icon: "checkmark.circle"
            )
            
            StatItem(
                title: "logs.stats.totalTokens".localized(),
                value: formatTokens(stats.totalTokens),
                icon: "text.word.spacing"
            )
            
            StatItem(
                title: "logs.stats.avgDuration".localized(),
                value: "\(stats.avgLatency)ms",
                icon: "clock"
            )
            
            Spacer()
            
            // Provider Filter
            if !stats.providers.isEmpty {
                Picker("Provider", selection: $requestFilterProvider) {
                    Text("logs.filter.allProviders".localized()).tag(nil as String?)
                    Divider()
                    ForEach(stats.providers.sorted(), id: \.self) { provider in
                        Text(provider.capitalized).tag(provider as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var filteredRequests: [TrackedRequest] {
        var requests = Array(requestTracker.recentRequests.reversed())
        
        if let provider = requestFilterProvider {
            requests = requests.filter { $0.provider == provider }
        }
        
        if !searchText.isEmpty {
            requests = requests.filter {
                $0.provider.localizedCaseInsensitiveContains(searchText) ||
                $0.model.localizedCaseInsensitiveContains(searchText) ||
                $0.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return requests
    }
    
    private func calculateStats() -> LogsRequestStats {
        let requests = filteredRequests
        let successful = requests.filter { $0.success }
        let totalTokens = requests.reduce(0) { $0 + ($1.tokens?.total ?? 0) }
        let totalLatency = requests.reduce(0) { $0 + $1.latencyMs }
        
        return LogsRequestStats(
            totalRequests: requests.count,
            successRate: requests.isEmpty ? 0 : Double(successful.count) / Double(requests.count),
            totalTokens: totalTokens,
            avgLatency: requests.isEmpty ? 0 : totalLatency / requests.count,
            providers: Array(Set(requests.map { $0.provider }))
        )
    }
    
    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    // MARK: - Proxy Logs View
    
    private var proxyLogsView: some View {
        Group {
            if logsViewModel.logs.isEmpty {
                ContentUnavailableView {
                    Label("logs.noProxyLogs".localized(), systemImage: "doc.text")
                } description: {
                    Text("logs.proxyLogsWillAppear".localized())
                }
            } else {
                LogsListView(logs: logsViewModel.logs, searchText: $searchText)
            }
        }
    }
}

// MARK: - Supporting Types

struct LogsRequestStats {
    let totalRequests: Int
    let successRate: Double
    let totalTokens: Int
    let avgLatency: Int
    let providers: [String]
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

struct RequestRow: View {
    let request: TrackedRequest
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(request.success ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            // Provider badge
            Text(request.provider)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.2))
                .clipShape(Capsule())
            
            // Model
            Text(request.model)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            // Path
            Text(request.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            // Latency
            Text("\(request.latencyMs)ms")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // Time
            Text(request.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct RequestDetailSheet: View {
    let request: TrackedRequest
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(request.model)
                        .font(.headline)
                    
                    Text(request.provider)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Details
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailRow(label: "Status", value: request.success ? "Success" : "Failed")
                DetailRow(label: "Latency", value: "\(request.latencyMs)ms")
                DetailRow(label: "Method", value: request.method)
                DetailRow(label: "Path", value: request.path)
                DetailRow(label: "Request Size", value: formatBytes(request.requestSize))
                DetailRow(label: "Response Size", value: formatBytes(request.responseSize))
                
                if let tokens = request.tokens {
                    DetailRow(label: "Input Tokens", value: "\(tokens.input)")
                    DetailRow(label: "Output Tokens", value: "\(tokens.output)")
                    DetailRow(label: "Total Tokens", value: "\(tokens.total)")
                }
            }
            
            if let statusCode = request.statusCode {
                HStack {
                    Text("Status Code:")
                        .foregroundStyle(.secondary)
                    Text("\(statusCode)")
                        .fontWeight(.medium)
                        .foregroundStyle(statusCode >= 200 && statusCode < 300 ? .green : .red)
                }
            }
            
            Spacer()
            
            // Timestamp
            Text("Requested at \(request.timestamp.formatted(date: .abbreviated, time: .standard))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func formatBytes(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1f MB", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1f KB", Double(count) / 1_000)
        } else {
            return "\(count) B"
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LogsListView: View {
    let logs: [LogEntry]
    @Binding var searchText: String
    
    var filteredLogs: [LogEntry] {
        if searchText.isEmpty {
            return logs
        }
        return logs.filter {
            $0.message.localizedCaseInsensitiveContains(searchText) ||
            $0.level.rawValue.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List(filteredLogs) { log in
            LogRow(entry: log)
        }
        .listStyle(.plain)
    }
}

struct LogRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            Circle()
                .fill(levelColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(entry.level.rawValue.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(levelColor.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                
                Text(entry.message)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    NavigationStack {
        LogsScreen()
    }
    .environment(QuotaViewModel())
    .environment(LogsViewModel())
}
