//
//  DaemonAuthService.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonAuthService {
    static let shared = DaemonAuthService()
    
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var authAccounts: [IPCAuthAccount] = []
    private(set) var oauthState: DaemonOAuthState?
    
    private let apiClient = QuotioAPIClient.shared
    
    private init() {}
    
    private func ensureConnected() async throws {
        try await apiClient.connect()
    }
    
    func listAuthFiles(provider: String? = nil) async -> [IPCAuthAccount] {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.listAuth(provider: provider)
            let accounts = result.auth_files.map { convertToIPCAuthAccount($0) }
            authAccounts = accounts
            return accounts
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }
    
    func deleteAuthFile(name: String) async throws {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.deleteAuth(name: name)
            if !result.success {
                throw DaemonAuthError.deleteFailed
            }
            authAccounts.removeAll { $0.name == name }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func startOAuth(provider: AIProvider, projectId: String? = nil) async throws -> DaemonOAuthState {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.startOAuth(provider: provider.rawValue)
            
            let state = DaemonOAuthState(
                url: result.auth_url,
                state: result.state,
                provider: provider,
                status: .pending
            )
            oauthState = state
            return state
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func pollOAuthStatus(state: String) async throws -> DaemonOAuthPollResult {
        guard let currentState = oauthState else {
            throw DaemonAuthError.oauthFailed("No active OAuth session")
        }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.pollOAuthStatus(
                provider: currentState.provider.rawValue,
                state: state
            )
            
            let status: DaemonOAuthStatus
            switch result.status {
            case "completed", "success":
                status = .completed
            case "failed", "error":
                status = .failed
            case "expired":
                status = .expired
            default:
                status = .pending
            }
            
            if status == .completed || status == .failed || status == .expired {
                oauthState = nil
            }
            
            return DaemonOAuthPollResult(
                status: status,
                email: result.email,
                error: result.error
            )
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func cancelOAuth() {
        oauthState = nil
    }
    
    // MARK: - Copilot Device Code Authentication
    
    func startCopilotAuth() async -> CopilotAuthResult {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            let result = try await apiClient.startDeviceCode(provider: "copilot")
            
            return CopilotAuthResult(
                success: true,
                deviceCode: result.user_code,
                message: "Please complete authentication in browser"
            )
        } catch {
            lastError = error.localizedDescription
            return CopilotAuthResult(success: false, message: error.localizedDescription)
        }
    }
    
    // MARK: - Kiro Authentication
    
    func startKiroAuth(method: AuthCommand) async -> KiroAuthResult {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        
        do {
            try await ensureConnected()
            
            switch method {
            case .kiroGoogleLogin:
                let result = try await apiClient.startOAuth(provider: "kiro")
                return KiroAuthResult(
                    success: true,
                    deviceCode: nil,
                    message: "Check browser for login"
                )
                
            case .kiroAWSLogin:
                let result = try await apiClient.startDeviceCode(provider: "kiro-aws")
                return KiroAuthResult(
                    success: true,
                    deviceCode: result.user_code,
                    message: "Check browser for AWS SSO"
                )
                
            case .kiroImport:
                // TODO: Implement kiro import endpoint when available
                return KiroAuthResult(success: false, message: "Kiro import not yet supported via HTTP API")
                
            default:
                return KiroAuthResult(success: false, message: "Unsupported Kiro auth method")
            }
        } catch {
            lastError = error.localizedDescription
            return KiroAuthResult(success: false, message: error.localizedDescription)
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertToIPCAuthAccount(_ file: AuthFileInfoAPI) -> IPCAuthAccount {
        IPCAuthAccount(
            id: file.id,
            name: file.name ?? file.id,
            provider: file.provider,
            email: file.email,
            status: file.status ?? "active",
            disabled: file.disabled
        )
    }
}

struct DaemonOAuthState: Sendable {
    let url: String
    let state: String
    let provider: AIProvider
    var status: DaemonOAuthStatus
}

enum DaemonOAuthStatus: String, Sendable {
    case pending
    case completed
    case failed
    case expired
}

struct DaemonOAuthPollResult: Sendable {
    let status: DaemonOAuthStatus
    let email: String?
    let error: String?
}

// MARK: - Copilot Auth Result

struct CopilotAuthResult {
    let success: Bool
    var deviceCode: String?
    let message: String
}

// MARK: - Kiro Auth Result

struct KiroAuthResult {
    let success: Bool
    var deviceCode: String?
    let message: String
}

enum DaemonAuthError: LocalizedError {
    case daemonNotRunning
    case deleteFailed
    case oauthFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .daemonNotRunning:
            return "Daemon is not running"
        case .deleteFailed:
            return "Failed to delete auth file"
        case .oauthFailed(let reason):
            return "OAuth failed: \(reason)"
        }
    }
}
