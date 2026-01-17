//
//  DaemonManager.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonManager {
    static let shared = DaemonManager()
    
    private(set) var isRunning = false
    private(set) var lastError: String?
    
    private var healthCheckTask: Task<Void, Never>?
    
    private init() {}
    
    func detectRunning() async {
        NSLog("[DaemonManager] detectRunning: checking server health...")
        let healthy = await checkHealth()
        NSLog("[DaemonManager] detectRunning: health check result = %@", healthy ? "true" : "false")
        
        if healthy {
            isRunning = true
            lastError = nil
            startHealthMonitoring()
        } else {
            isRunning = false
        }
    }
    
    func start() async throws {
        NSLog("[DaemonManager] start: called, isRunning=%@", isRunning ? "true" : "false")
        if isRunning { return }
        
        NSLog("[DaemonManager] start: checking if server is reachable...")
        if await checkHealth() {
            NSLog("[DaemonManager] start: server is healthy")
            isRunning = true
            lastError = nil
            startHealthMonitoring()
            return
        }
        
        NSLog("[DaemonManager] start: server not reachable")
        lastError = "Server not running. Please start the server with 'bun run dev' or ensure it's running as a service."
        throw DaemonError.connectionFailed
    }
    
    func stop() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        if await checkHealth() {
            do {
                try await QuotioAPIClient.shared.shutdown(graceful: true)
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {
                NSLog("[DaemonManager] stop: shutdown request failed: %@", error.localizedDescription)
            }
        }
        
        isRunning = false
    }
    
    func restart() async throws {
        await stop()
        try await Task.sleep(nanoseconds: 500_000_000)
        try await start()
    }
    
    func checkHealth() async -> Bool {
        let healthy = await QuotioAPIClient.shared.health()
        if healthy {
            NSLog("[DaemonManager] checkHealth: server is healthy")
        } else {
            NSLog("[DaemonManager] checkHealth: server health check failed")
        }
        return healthy
    }
    
    private func startHealthMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                
                if Task.isCancelled { break }
                
                let healthy = await checkHealth()
                if !healthy && isRunning {
                    isRunning = false
                    lastError = "Server health check failed"
                    NSLog("[DaemonManager] Health check failed, marking as not running")
                } else if healthy && !isRunning {
                    isRunning = true
                    lastError = nil
                    NSLog("[DaemonManager] Health check succeeded, marking as running")
                }
            }
        }
    }
}

enum DaemonError: LocalizedError {
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to server"
        }
    }
}
