//
//  DaemonAgentService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonAgentService {
    static let shared = DaemonAgentService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var agents: [AgentStatus] = []
    private(set) var lastDetected: Date?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    // MARK: - Agent Detection
    
    func detectAllAgents(forceRefresh: Bool = false) async -> [AgentStatus] {
        do {
            try await ensureConnected()
        } catch {
            lastError = "Server not running"
            return []
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.detectAgents(forceRefresh: forceRefresh)
            agents = convertAgents(result.agents)
            lastDetected = Date()
            return agents
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
    
    // MARK: - Agent Configuration
    
    func configureAgent(
        agent: CLIAgent,
        mode: ConfigurationMode
    ) async -> AgentConfigResult? {
        do {
            try await ensureConnected()
        } catch {
            lastError = "Server not running"
            return nil
        }
        
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            let result = try await apiClient.configureAgent(
                agent: agent.rawValue,
                mode: mode.rawValue
            )
            
            if result.success {
                _ = await detectAllAgents(forceRefresh: true)
                
                return AgentConfigResult.success(
                    type: agent.configType,
                    mode: mode,
                    configPath: result.configPath,
                    instructions: result.instructions,
                    backupPath: result.backupPath
                )
            } else {
                return AgentConfigResult.failure(error: result.error ?? "Configuration failed")
            }
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Helpers
    
    func getAgentStatus(for agent: CLIAgent) -> AgentStatus? {
        agents.first { $0.agent == agent }
    }
    
    func installedAgents() -> [AgentStatus] {
        agents.filter { $0.installed }
    }
    
    func configuredAgents() -> [AgentStatus] {
        agents.filter { $0.configured }
    }
    
    func unconfiguredInstalledAgents() -> [AgentStatus] {
        agents.filter { $0.installed && !$0.configured }
    }
    
    // MARK: - Conversion
    
    private func convertAgents(_ apiAgents: [AgentInfoAPI]) -> [AgentStatus] {
        apiAgents.compactMap { apiAgent in
            guard let agent = CLIAgent(rawValue: apiAgent.id) else { return nil }
            
            return AgentStatus(
                agent: agent,
                installed: apiAgent.installed,
                configured: apiAgent.configured,
                binaryPath: nil,
                version: apiAgent.version,
                lastConfigured: nil
            )
        }.sorted { $0.agent.displayName < $1.agent.displayName }
    }
}
