//
//  DaemonManager.swift
//  Quotio
//

import Foundation

@MainActor @Observable
final class DaemonManager {
    static let shared = DaemonManager()
    
    private(set) var isRunning = false
    private(set) var daemonPID: Int32?
    private(set) var lastError: String?
    
    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?
    private let ipcClient = DaemonIPCClient.shared
    
    private init() {}
    
    func detectRunning() async {
        guard FileManager.default.fileExists(atPath: socketPath) else {
            NSLog("[DaemonManager] detectRunning: socket not found at %@", socketPath)
            isRunning = false
            return
        }
        
        NSLog("[DaemonManager] detectRunning: socket exists, checking health...")
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
    
    var daemonBinaryPath: URL {
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("quotio-cli"),
           FileManager.default.fileExists(atPath: bundleURL.path) {
            return bundleURL
        }
        
        let bundlePath = Bundle.main.bundleURL.path
        
        if bundlePath.contains("/Build/Products/") {
            if let range = bundlePath.range(of: "/build/") {
                let projectRoot = String(bundlePath[..<range.lowerBound])
                let devPath = URL(fileURLWithPath: projectRoot).appendingPathComponent("quotio-cli/dist/quotio")
                if FileManager.default.fileExists(atPath: devPath.path) {
                    return devPath
                }
            }
        }
        
        let projectRoot = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return projectRoot.appendingPathComponent("quotio-cli/dist/quotio")
    }
    
    var socketPath: String {
        // Must match quotio-cli: macOS uses ~/Library/Caches, Linux uses ~/.cache
        #if os(macOS)
        FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Caches/quotio-cli/quotio.sock"
        #else
        FileManager.default.homeDirectoryForCurrentUser.path + "/.cache/quotio-cli/quotio.sock"
        #endif
    }
    
    func start() async throws {
        NSLog("[DaemonManager] start: called, isRunning=%@", isRunning ? "true" : "false")
        if isRunning { return }
        
        // First check if a daemon is already running (started externally)
        if FileManager.default.fileExists(atPath: socketPath) {
            NSLog("[DaemonManager] start: socket exists, checking health...")
            if await checkHealth() {
                NSLog("[DaemonManager] start: external daemon is healthy, using it")
                isRunning = true
                lastError = nil
                startHealthMonitoring()
                return
            }
            NSLog("[DaemonManager] start: health check failed, will try to start new daemon")
        }
        
        guard FileManager.default.fileExists(atPath: daemonBinaryPath.path) else {
            NSLog("[DaemonManager] start: binary not found at %@", daemonBinaryPath.path)
            throw DaemonError.binaryNotFound
        }
        
        try await ensureSocketDirectoryExists()
        
        let proc = Process()
        proc.executableURL = daemonBinaryPath
        proc.arguments = ["daemon", "start", "--foreground"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        
        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleTermination(exitCode: process.terminationStatus)
            }
        }
        
        do {
            try proc.run()
            process = proc
            daemonPID = proc.processIdentifier
            
            try await waitForSocket(timeout: 5.0)
            isRunning = true
            lastError = nil
            startHealthMonitoring()
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    func stop() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil
        
        if await checkHealth() {
            do {
                try await ipcClient.shutdown(graceful: true)
                try? await Task.sleep(nanoseconds: 500_000_000)
            } catch {}
        }
        
        if let proc = process, proc.isRunning {
            proc.terminate()
            try? await Task.sleep(nanoseconds: 200_000_000)
            if proc.isRunning {
                proc.interrupt()
            }
        }
        
        process = nil
        daemonPID = nil
        isRunning = false
    }
    
    func restart() async throws {
        await stop()
        try await Task.sleep(nanoseconds: 500_000_000)
        try await start()
    }
    
    func checkHealth() async -> Bool {
        do {
            let result = try await ipcClient.ping()
            NSLog("[DaemonManager] checkHealth: ping succeeded, pong = %@", result.pong ? "true" : "false")
            return result.pong
        } catch {
            NSLog("[DaemonManager] checkHealth: ping failed with error: %@", error.localizedDescription)
            return false
        }
    }
    
    private func ensureSocketDirectoryExists() async throws {
        let dir = (socketPath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: dir) {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
    }
    
    private func waitForSocket(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: socketPath) {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if await checkHealth() {
                    return
                }
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        throw DaemonError.startupTimeout
    }
    
    private func startHealthMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                
                if Task.isCancelled { break }
                
                let healthy = await checkHealth()
                if !healthy && isRunning {
                    // Don't disconnect - just mark as not running
                    // The IPC client will reconnect on next request if needed
                    isRunning = false
                    lastError = "Daemon health check failed"
                    NSLog("[DaemonManager] Health check failed, marking as not running")
                } else if healthy && !isRunning {
                    isRunning = true
                    lastError = nil
                }
            }
        }
    }
    
    private func handleTermination(exitCode: Int32) {
        isRunning = false
        daemonPID = nil
        process = nil
        
        if exitCode != 0 {
            lastError = "Daemon exited with code \(exitCode)"
        }
    }
}

enum DaemonError: LocalizedError {
    case binaryNotFound
    case startupTimeout
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Daemon binary not found in app bundle"
        case .startupTimeout:
            return "Daemon failed to start within timeout"
        case .connectionFailed:
            return "Failed to connect to daemon"
        }
    }
}
