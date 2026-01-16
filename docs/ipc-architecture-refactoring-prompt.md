 # IPC Architecture Refactoring Prompt
 
 **Created:** 2026-01-16
 **Status:** Implementation Complete - Awaiting Manual Testing
 **Priority:** Critical
 
 ## Problem Statement
 
 The current daemon IPC architecture has a critical bug causing "Daemon IPC: Inactive" false negatives in the Swift UI despite the daemon running and responding correctly to manual `nc` tests. Multiple debugging attempts have failed to resolve the issue.
 
 ## Current Architecture
 
 ```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                         Swift/Tauri GUI App                            │
 │  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────┐  │
 │  │ DaemonIPCClient     │  │ DaemonProxyConfig   │  │ DaemonAPIKeys  │  │
 │  │ (actor, singleton)  │  │ Service             │  │ Service        │  │
 │  └──────────┬──────────┘  └──────────┬──────────┘  └───────┬────────┘  │
 │             │                        │                      │          │
 │             └────────────────────────┼──────────────────────┘          │
 │                                      │                                 │
 │                       Unix Socket IPC (quotio.sock)                    │
 │                       ~/Library/Caches/quotio-cli/quotio.sock          │
 └──────────────────────────────────────┼─────────────────────────────────┘
                                        ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      quotio-cli daemon (Bun/TypeScript)                │
 │  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────┐  │
 │  │ IPC Server          │  │ Daemon Handlers     │  │ Proxy Process  │  │
 │  │ (Bun.listen)        │  │ (58 methods)        │  │ Manager        │  │
 │  └──────────┬──────────┘  └──────────┬──────────┘  └───────┬────────┘  │
 │             │                        │                      │          │
 │             └────────────────────────┼──────────────────────┘          │
 │                                      │                                 │
 │                         HTTP (localhost:18317)                         │
 └──────────────────────────────────────┼─────────────────────────────────┘
                                        ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      CLIProxyAPI (Go binary)                           │
 │  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────┐  │
 │  │ Proxy Server        │  │ Auth Management     │  │ Request Router │  │
 │  └─────────────────────┘  └─────────────────────┘  └────────────────┘  │
 └────────────────────────────────────────────────────────────────────────┘
 ```
 
 ## Known Issues
 
 ### Issue 1: Swift DaemonIPCClient Race Condition
 - **Location:** `Quotio/Services/Daemon/DaemonIPCClient.swift`
 - **Problem:** Multiple concurrent `connect()` calls can race, causing one to fail
 - **Attempted Fix:** Added wait loop for connecting state, but issue persists
 
 ### Issue 2: Read Loop Weak Self + Actor Isolation
 - **Location:** `DaemonIPCClient.swift:startReadLoop()`
 - **Problem:** `Task.detached { [weak self] ... }` with actor calls may have timing issues
 - **Symptom:** Response data received but not matched to pending requests
 
 ### Issue 3: JSON-RPC Version Mismatch
 - **Swift side:** Sends `{ "id": 1, "method": "daemon.ping", "params": {} }` (missing `jsonrpc: "2.0"`)
 - **TypeScript side:** Expects `{ "jsonrpc": "2.0", ... }` and validates it
 
 ### Issue 4: State Management Complexity
 - **Problem:** `DaemonManager.isRunning` can become stale
 - Multiple services check `daemonManager.isRunning` before calling IPC
 - Health monitoring may reset state incorrectly
 
 ## Key Files to Refactor
 
 ### Swift Side
 1. **`Quotio/Services/Daemon/DaemonIPCClient.swift`** - Core IPC client (actor)
 2. **`Quotio/Services/Daemon/DaemonManager.swift`** - Daemon lifecycle (@MainActor)
 3. **`Quotio/Services/Daemon/IPCProtocol.swift`** - IPC types and methods
 
 ### TypeScript Side
 1. **`quotio-cli/src/ipc/server.ts`** - Bun socket server
 2. **`quotio-cli/src/ipc/protocol.ts`** - JSON-RPC protocol types
 3. **`quotio-cli/src/services/daemon/service.ts`** - Handler implementations
 
 ## Refactoring Requirements
 
 ### 1. Fix JSON-RPC Compliance
 Ensure Swift sends proper JSON-RPC 2.0 requests:
 ```json
 {
   "jsonrpc": "2.0",
   "id": 1,
   "method": "daemon.ping",
   "params": {}
 }
 ```
 
 ### 2. Simplify Connection Management
 Replace complex state machine with simpler approach:
 - Single connection per client lifetime
 - Auto-reconnect on disconnect
 - No concurrent connection attempts
 
 ### 3. Fix Read Loop Actor Isolation
 Options:
 - Use `Task` instead of `Task.detached`
 - Use `@unchecked Sendable` wrapper for socket operations
 - Implement proper async stream for reading
 
 ### 4. Unify State Management
 - `DaemonManager.isRunning` should be derived from actual connection state
 - Remove redundant health check loops
 - Single source of truth for daemon availability
 
 ### 5. Add Proper Error Propagation
 - IPC errors should bubble up to UI
 - Clear error messages for common failures
 - Recovery suggestions for users
 
 ### 6. Improve Logging
 Add structured logging at key points:
 - Connection attempts (with socket path)
 - Request/response pairs (with method and id)
 - State transitions
 - Error conditions
 
 ## Proposed New Architecture
 
 ```swift
 // Option A: Event-Driven Connection
 actor DaemonIPCClient {
     enum ConnectionEvent {
         case connected
         case disconnected(Error?)
         case messageReceived(Data)
     }
     
     private let eventStream: AsyncStream<ConnectionEvent>
     private var connection: DaemonConnection?
     
     // Single connection lifecycle
     func ensureConnected() async throws
     func disconnect()
     
     // Request/response with automatic reconnection
     func call<P, R>(_ method: IPCMethod, params: P) async throws -> R
 }
 
 // Option B: Synchronous Connection Check
 actor DaemonIPCClient {
     private var socket: SocketHandle?
     
     var isConnected: Bool { socket?.isValid ?? false }
     
     func call<P, R>(_ method: IPCMethod, params: P) async throws -> R {
         if !isConnected {
             try await connect()
         }
         return try await sendAndReceive(method, params)
     }
 }
 ```
 
 ## Test Cases
 
 After refactoring, these scenarios must work:
 
 1. **Cold Start:** App launches → daemon not running → start daemon → UI shows "Active"
 2. **External Daemon:** Daemon started via CLI → App launches → detects and shows "Active"
 3. **Daemon Restart:** Daemon stops → Auto-reconnect → UI recovers to "Active"
 4. **Concurrent Requests:** Multiple IPC calls at once → All succeed
 5. **Socket Not Found:** No daemon → Clear error message → Offer to start
 
 ## Acceptance Criteria
 
 - [ ] `daemon.ping` succeeds consistently when daemon is running
 - [ ] UI correctly reflects daemon state within 1 second
 - [ ] No race conditions in connection management
 - [ ] Proper JSON-RPC 2.0 compliance
 - [ ] Clear error messages for all failure modes
 - [ ] Logging enables debugging without code changes
 - [ ] Works with both Swift app and future Tauri app
 
 ## Files to Deliver
 
 1. Refactored `DaemonIPCClient.swift`
 2. Refactored `DaemonManager.swift`
 3. Updated `IPCProtocol.swift` (if needed)
 4. Any TypeScript changes to `ipc/server.ts` or `protocol.ts`
 5. Test plan document
 
 ## References
 
 - [Daemon Migration Guide](./daemon-migration-guide.md)
 - [CLI Migration PRD](./quotio-cli-migration-prd.md)
 - [Codebase Architecture](./codebase-structure-architecture-code-standards.md)
