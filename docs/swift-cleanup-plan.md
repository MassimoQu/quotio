# Swift Code Cleanup Plan

**Created:** 2026-01-13
**Updated:** 2026-01-15
**Branch:** feat/universal-provider-architecture  
**Status:** Ready for Implementation - All TS equivalents ported

## Overview

Migration plan to remove redundant Swift code after business logic has been ported to the TypeScript `quotio-cli`. 

### Summary

| Category | Files | Lines | Status |
|----------|-------|-------|--------|
| Deprecated code (can delete) | 2 | 875 | Ready |
| QuotaFetchers (TS ported) | 6 | 2,217 | Ready after migration |
| FallbackFormatConverter | 1 | 63 | ✅ **Already simplified** (was 1,190) |
| ProxyBridge (simplify) | 1 | ~40 lines removable | Ready after Phase 2 |
| **Total potential cleanup** | **10 files** | **~3,195 lines** | |

### Recent Progress (2026-01-15)

**Commit e1ed27a** (`refactor(fallback): simplify fallback logic by removing format conversion`) completed Phase 3.4 early:
- `FallbackFormatConverter.swift` reduced from 1,190 → 63 lines
- Added `ModelType` enum to `FallbackModels.swift` for same-type-only fallback
- Fallback now only works between models of same type (Claude→Claude, GPT→GPT, etc.)
- Cross-format conversion logic removed - no longer needed

---

## What Was Already Ported to TypeScript

All quota fetchers and format converter have been ported to `quotio-cli`:

| CLI (TypeScript) | Swift Original | Swift Lines | TS Lines | Status |
|------------------|----------------|-------------|----------|--------|
| `format-converter.ts` | `FallbackFormatConverter.swift` | 63 | 1,306 | ⚠️ Swift simplified (error detection only) |
| `quota-fetchers/kiro.ts` | `KiroQuotaFetcher.swift` | 519 | 560 | ✅ Ported + Tested |
| `quota-fetchers/claude.ts` | `ClaudeCodeQuotaFetcher.swift` | 364 | 189 | ✅ Ported + Tested |
| `quota-fetchers/copilot.ts` | `CopilotQuotaFetcher.swift` | 487 | 270 | ✅ Ported + Tested |
| `quota-fetchers/openai.ts` | `OpenAIQuotaFetcher.swift` | 291 | 234 | ✅ Ported |
| `quota-fetchers/gemini.ts` | `GeminiCLIQuotaFetcher.swift` | 186 | 107 | ✅ Ported |
| `quota-fetchers/codex.ts` | `CodexCLIQuotaFetcher.swift` | 370 | 254 | ✅ Ported |
| `quota-fetchers/antigravity.ts` | `AntigravityQuotaFetcher.swift` | 843 | 338 | ✅ Ported |
| `quota-fetchers/cursor.ts` | `CursorQuotaFetcher.swift` | 406 | 284 | ✅ Ported (KEEP Swift) |
| `quota-fetchers/trae.ts` | `TraeQuotaFetcher.swift` | 368 | 356 | ✅ Ported (KEEP Swift) |
| `management-api.ts` | `ManagementAPIClient.swift` | 726 | 368 | ✅ Ported |

---

## Phase 1: Immediate Cleanup (Safe Deletions)

Files that are already deprecated and have no/minimal dependencies.

### 1.1 Delete `AppMode.swift` (149 lines)

| Property | Value |
|----------|-------|
| File | `Quotio/Models/AppMode.swift` |
| Status | `@available(*, deprecated)` |
| Replacement | `OperatingMode.swift` |
| Dependencies | Only referenced in `OperatingMode.swift` for backward compat |

**Steps:**
```bash
# 1. Remove any imports/references in OperatingMode.swift
# 2. Delete the file
rm Quotio/Models/AppMode.swift
# 3. Verify build
xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Debug build
```

### 1.2 Migrate `ManagementAPIClient` Usages (726 lines)

| Property | Value |
|----------|-------|
| File | `Quotio/Services/ManagementAPIClient.swift` |
| Status | `@available(*, deprecated)` |
| Replacement | `DaemonIPCClient` |
| Dependencies | 4 files still using it |

**Files to migrate:**

| File | Current Usage | Migrate To |
|------|---------------|------------|
| `ViewModels/LogsViewModel.swift:15,25` | `ManagementAPIClient` for logs | `DaemonIPCClient.fetchLogs()` |
| `ViewModels/QuotaViewModel.swift:15,17,296,966` | `ManagementAPIClient` for remote mode | `DaemonIPCClient.remoteSetConfig()` |
| `Views/Screens/SettingsScreen.swift:335,592` | Remote mode config | `DaemonProxyConfigService` |
| `Models/ConnectionMode.swift:136` | Base URL extraction | Keep for remote mode display only |

**Steps:**
```swift
// 1. In LogsViewModel.swift, replace:
private var apiClient: ManagementAPIClient?
// With:
private let ipcClient = DaemonIPCClient.shared

// 2. Replace API calls:
// OLD: try await apiClient?.fetchLogs()
// NEW: try await ipcClient.fetchLogs()

// 3. After all migrations complete, delete ManagementAPIClient.swift
```

---

## Phase 2: Move Fallback Logic to CLI (HIGH Priority)

The fallback/retry logic currently lives in `ProxyBridge.swift` (930 lines). Move it to CLI for cross-platform support.

| ID | Task | Status |
|----|------|--------|
| 2.1 | Add Virtual Model / fallback chain support to CLI proxy | [ ] |
| 2.2 | Move fallback settings API from `FallbackSettingsManager.swift` to CLI IPC | [ ] |
| 2.3 | Implement same-type retry logic in CLI (retry on 429/5xx) | [ ] |
| 2.4 | Update `FallbackSettingsManager.swift` to sync with CLI config | [ ] |

> **Note**: Format conversion is no longer needed - fallback only works between same model types (ModelType enum in FallbackModels.swift).

**After Phase 2 completion, proceed to Phase 3.**

---

## Phase 3: Simplify ProxyBridge (MEDIUM Priority)

Once CLI handles fallback, simplify `ProxyBridge.swift` from 930 lines to ~200 lines.

| ID | Task | Status |
|----|------|--------|
| 3.1 | Remove `FallbackFormatConverter` usage from `ProxyBridge.swift` | [ ] |
| 3.2 | Remove `FallbackContext` and fallback retry logic | [ ] |
| 3.3 | Keep only TCP passthrough with `Connection: close` header | [ ] |
| 3.4 | ~~Delete `FallbackFormatConverter.swift` (1,190 lines)~~ | ✅ **DONE** - reduced to 63 lines (error detection only) |
| 3.5 | Update `RequestTracker` to consume metrics from CLI API | [ ] |

> **Note**: Phase 3.4 completed early in commit `e1ed27a`. FallbackFormatConverter now only contains error detection logic (63 lines).

---

## Phase 4: Delete QuotaFetchers (After Phase 1.2)

After `QuotaViewModel` is migrated to use `DaemonIPCClient.fetchQuotas()`:

| ID | File to Delete | Lines | Reason |
|----|----------------|-------|--------|
| 4.1 | `QuotaFetchers/KiroQuotaFetcher.swift` | 519 | TS equivalent: `kiro.ts` |
| 4.2 | `QuotaFetchers/ClaudeCodeQuotaFetcher.swift` | 364 | TS equivalent: `claude.ts` |
| 4.3 | `QuotaFetchers/CopilotQuotaFetcher.swift` | 487 | TS equivalent: `copilot.ts` |
| 4.4 | `QuotaFetchers/OpenAIQuotaFetcher.swift` | 291 | TS equivalent: `openai.ts` |
| 4.5 | `QuotaFetchers/GeminiCLIQuotaFetcher.swift` | 186 | TS equivalent: `gemini.ts` |
| 4.6 | `QuotaFetchers/CodexCLIQuotaFetcher.swift` | 370 | TS equivalent: `codex.ts` |
| **Total** | | **2,217** | |

**Steps for each fetcher:**
```bash
# 1. Verify TS equivalent works via daemon
cd quotio-cli && bun test

# 2. Update QuotaViewModel to use DaemonIPCClient
# Replace: let result = await KiroQuotaFetcher.shared.fetch()
# With: let result = try await DaemonIPCClient.shared.fetchQuotas(provider: "kiro")

# 3. Delete Swift file
rm Quotio/Services/QuotaFetchers/KiroQuotaFetcher.swift

# 4. Verify build
xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Debug build
```

---

## Phase 5: Files to KEEP (DO NOT DELETE)

These Swift files must remain - they handle macOS-specific functionality.

### Core Services (KEEP)

| File | Reason |
|------|--------|
| `Daemon/DaemonIPCClient.swift` | IPC client - core communication layer |
| `Daemon/DaemonManager.swift` | Daemon lifecycle management |
| `Daemon/DaemonProxyService.swift` | Proxy operations via IPC |
| `Daemon/DaemonQuotaService.swift` | Quota fetching via IPC |
| `Daemon/DaemonAuthService.swift` | Auth management via IPC |
| `Daemon/DaemonLogsService.swift` | Logs via IPC |
| `Daemon/DaemonConfigService.swift` | Config via IPC |
| `Daemon/DaemonProxyConfigService.swift` | Proxy config via IPC |
| `Daemon/DaemonAPIKeysService.swift` | API keys via IPC |
| `Daemon/IPCProtocol.swift` | IPC types and protocol |
| `Proxy/CLIProxyManager.swift` | macOS process lifecycle, binary management |
| `Proxy/ProxyStorageManager.swift` | Versioned binary storage, rollback |
| `Proxy/ProxyBridge.swift` (thinned) | TCP passthrough only (~200 lines after cleanup) |
| `Proxy/FallbackFormatConverter.swift` | Error detection only (63 lines) |
| `KeychainService.swift` | macOS Keychain integration |
| `StatusBarManager.swift` | macOS menu bar integration |
| `StatusBarMenuBuilder.swift` | NSMenu construction |
| `NotificationManager.swift` | macOS notifications |
| `FallbackSettingsManager.swift` | UI state (becomes thin wrapper to CLI config) |
| `AgentDetectionService.swift` | macOS filesystem scanning |
| `AgentConfigurationService.swift` | macOS config file management |
| `UniversalProviderService.swift` | Provider management |

### QuotaFetchers to KEEP (macOS-specific)

| File | Lines | Reason |
|------|-------|--------|
| `CursorQuotaFetcher.swift` | 406 | Reads local SQLite from Cursor app |
| `TraeQuotaFetcher.swift` | 368 | Reads local JSON from Trae IDE |

### Antigravity Suite (KEEP - 2,023 lines total)

| File | Lines | Reason |
|------|-------|--------|
| `AntigravityQuotaFetcher.swift` | 843 | Complex quota + account management |
| `AntigravityDatabaseService.swift` | 378 | SQLite DB injection |
| `AntigravityProtobufHandler.swift` | 313 | Protobuf parsing |
| `AntigravityAccountSwitcher.swift` | 283 | Account switching |
| `AntigravityProcessManager.swift` | 206 | IDE process management |

---

## Phase 6: Final Verification (HIGH Priority)

| ID | Test | Command | Status |
|----|------|---------|--------|
| 6.1 | CLI tests pass | `cd quotio-cli && bun test` | [ ] |
| 6.2 | Swift app builds | `xcodebuild -scheme Quotio -configuration Debug build` | [ ] |
| 6.3 | E2E: Proxy routing works | Manual test with AI agent | [ ] |
| 6.4 | E2E: Fallback retry works | Trigger 429 → verify retry | [ ] |
| 6.5 | E2E: Token refresh works | Expire Kiro token → verify refresh | [ ] |
| 6.6 | ~~Update documentation~~ | ~~Fix ports in AGENTS.md~~ | ✅ Verified correct |

---

## Phase 7: Documentation Fixes

**Status:** ✅ **VERIFIED CORRECT** (2026-01-15)

The documentation accurately reflects the dual-port architecture:
- **Port 8317** = ProxyBridge.swift (client-facing, what CLI agents connect to)
- **Port 18317** = CLIProxyAPI Go binary (internal, ProxyBridge forwards here)

| File | Line | Current Value | Status |
|------|------|---------------|--------|
| `AGENTS.md:85` | daemon → CLIProxyAPI | `18317` | ✅ Correct (internal) |
| `AGENTS.md:212` | ProxyBridge.swift | `8317` | ✅ Correct (client-facing) |
| `AGENTS.md:216` | CLIProxyAPI | `18317` | ✅ Correct (internal) |
| `docs/daemon-migration-guide.md:14` | CLIProxyAPI | `18317` | ✅ Correct (internal) |

**No changes needed.** Original plan had incorrect assumption about port usage.

---

## Dependency Graph

```
BEFORE CLEANUP (Current State):

CLIProxyManager
├── ProxyBridge (930 lines: TCP + Fallback, simplified format handling)
│   ├── FallbackFormatConverter (63 lines: error detection only)
│   └── FallbackSettingsManager
├── ProxyStorageManager
└── QuotaFetchers (Swift)
    ├── KiroQuotaFetcher (519 lines) ← DELETE
    ├── ClaudeCodeQuotaFetcher (364 lines) ← DELETE
    ├── CopilotQuotaFetcher (487 lines) ← DELETE
    ├── OpenAIQuotaFetcher (291 lines) ← DELETE
    ├── GeminiCLIQuotaFetcher (186 lines) ← DELETE
    ├── CodexCLIQuotaFetcher (370 lines) ← DELETE
    ├── CursorQuotaFetcher (406 lines) ← KEEP
    └── TraeQuotaFetcher (368 lines) ← KEEP

ViewModels
├── QuotaViewModel
│   └── ManagementAPIClient (726 lines) ← DELETE after migration
└── LogsViewModel
    └── ManagementAPIClient ← DELETE after migration

Models
├── AppMode.swift (149 lines) ← DELETE immediately
└── FallbackModels.swift ← KEEP (has ModelType enum for same-type fallback)

---

AFTER CLEANUP (Target State):

CLIProxyManager
├── ProxyBridge (~200 lines: TCP passthrough only)
├── ProxyStorageManager
└── DaemonIPCClient (IPC to quotio-cli)

QuotaFetchers (Swift - macOS only)
├── CursorQuotaFetcher (KEEP - local SQLite)
└── TraeQuotaFetcher (KEEP - local JSON)

quotio-cli daemon (TypeScript):
├── format-converter.ts (all format conversion - for future cross-type fallback if needed)
├── quota-fetchers/* (all provider quotas via API)
└── fallback/routing logic (same-type only)
```

---

## Implementation Timeline

| Week | Phase | Tasks | Lines Removed |
|------|-------|-------|---------------|
| 1 | Phase 1 | Delete AppMode.swift, Migrate ManagementAPIClient | 875 |
| 2 | Phase 4 | Delete 6 QuotaFetchers | 2,217 |
| 3 | Phase 2-3 | Move fallback to CLI, Simplify ProxyBridge | ~40 |
| 4 | Phase 6-7 | Testing, Documentation | 0 |
| **Total** | | | **~3,132 lines** |

> **Note**: Original estimate was ~5,052 lines. Reduced to ~3,132 because FallbackFormatConverter was already simplified (1,190 → 63 lines saved 1,127 lines early).

---

## Notes

- **IDE Monitors** (Cursor, Trae) stay in Swift - they read local SQLite/JSON
- **Antigravity suite** stays in Swift due to complex Protobuf DB injection and IDE process management
- **FallbackSettingsManager** becomes thin wrapper syncing UI state to CLI config
- **FallbackFormatConverter** already simplified to error detection only (63 lines) - keep in Swift
- **ModelType enum** in FallbackModels.swift enforces same-type-only fallback (Claude→Claude, GPT→GPT, etc.)
- Test thoroughly on real accounts before deleting any quota fetcher
- Delete one file at a time and verify build after each deletion

---

## Commands Reference

```bash
# Verify CLI tests pass
cd quotio-cli && bun test

# Verify CLI builds
cd quotio-cli && bun run build

# Verify Swift builds
xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Debug build

# Check for remaining usages before deletion
rg "KiroQuotaFetcher" Quotio/ --line-number

# Delete a file safely
git rm Quotio/Services/QuotaFetchers/KiroQuotaFetcher.swift

# Verify no compile errors
xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Debug build 2>&1 | grep -E "error:|warning:"
```
