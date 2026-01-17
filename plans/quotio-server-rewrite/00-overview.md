# Quotio Server Rewrite - Executive Summary

**Created:** 2026-01-17
**Updated:** 2026-01-17
**Project:** Quotio Monorepo + TypeScript Proxy Server
**Estimated Effort:** 12-14 weeks (1 developer)

## Problem Statement

Current architecture has 3 layers of communication:
```
Swift App (16,500 LOC) → IPC → quotio-cli daemon (16,000 LOC) → HTTP → CLIProxyAPI (Go, 82,500 LOC)
```

### Issues
1. **Complexity**: 3 layers = hard to debug, maintain
2. **No Control**: CLIProxyAPI is external Go binary - can't customize
3. **Platform Lock**: Swift app only works on macOS
4. **Duplication**: Logic split between Swift/TypeScript/Go
5. **Sync Issues**: Management key synchronization problems between layers

## Target Architecture

```
Frontend (Swift/Tauri) → HTTP/WebSocket → quotio-server (TypeScript/Bun)
```

### Benefits
- **2 layers** instead of 3
- **Single TypeScript backend** for all platforms
- **Full control** over proxy logic
- **Shared types** between CLI and server
- **Cross-platform** via Tauri (Windows/Linux/macOS)

## Scope

### In Scope
1. Monorepo structure with Bun workspaces + Turborepo
2. quotio-server: Complete TypeScript rewrite of CLIProxyAPI
3. quotio-cli refactoring to use shared packages
4. Migration strategy with backward compatibility
5. **Proxy pass-through** to CLIProxyAPI during migration

### Out of Scope
1. Tauri app implementation (future phase)
2. Swift app modifications (minimal changes only)
3. New features beyond parity with CLIProxyAPI

## Feature Parity Checklist

### Core Proxy Features
- [ ] HTTP proxy server (OpenAI-compatible `/v1/*` endpoints)
- [ ] Claude Messages API (`/v1/messages`)
- [ ] Gemini API (`/v1beta/*`)
- [ ] Request/response format translation (matrix of 6 protocols)
- [ ] SSE streaming support
- [ ] Request retry with exponential backoff
- [ ] Rate limit handling (429 → next credential)

### Authentication (10+ Providers)
- [ ] Gemini CLI (OAuth2 + PKCE)
- [ ] Claude (OAuth2)
- [ ] Codex/OpenAI (OAuth2)
- [ ] GitHub Copilot (Device Code flow)
- [ ] Vertex AI (Service Account JSON)
- [ ] iFlow (OAuth2)
- [ ] Antigravity (OAuth2)
- [ ] Kiro/AWS CodeWhisperer (OAuth2)
- [ ] Qwen (OAuth2)
- [ ] Custom OpenAI-compatible providers (API Key)

### Management API
- [ ] Auth file CRUD (`/v0/management/auth-files`)
- [ ] Usage statistics (`/v0/management/usage`)
- [ ] Request logs (`/v0/management/logs`)
- [ ] Configuration (`/v0/management/config`)
- [ ] API key management (`/v0/management/api-keys`)
- [ ] OAuth flow initiation/polling
- [ ] WebSocket for real-time updates

### Advanced Features
- [ ] Fallback/failover chains (Virtual Models)
- [ ] Quota tracking per provider
- [ ] Model aliasing and exclusions
- [ ] Payload manipulation (default/override rules)
- [ ] **Thinking mode handling** (Claude 3.7+, O1)
- [ ] Token store backends (File, PostgreSQL, Git, S3)

### Resilience Features (from LLM-API-Key-Proxy patterns)
- [ ] Escalating cooldowns (10s → 30s → 60s → 120s)
- [ ] Key-level lockouts for failing credentials
- [ ] Quota groups (shared cooldowns for related models)
- [ ] Priority tiers (paid credentials before free)
- [ ] Rotation modes (balanced vs sequential)
- [ ] Background quota refresh
- [ ] Model filtering (whitelist/blacklist)

## Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Runtime | Bun 1.1+ | Fast, native TS, built-in SQLite |
| HTTP Framework | Hono | Fast, TypeScript-native, edge-ready |
| Validation | Zod | Type-safe schemas, transforms |
| Database | SQLite (Bun native) | Simple, embedded, fast |
| Auth | oslo/arctic | Modern OAuth2/PKCE library |
| Testing | Bun test | Built-in, fast |
| Monorepo | Turborepo | Caching, parallelization |

## Reference Implementations

### CLIProxyAPIPlus (Go) - Primary Reference
- **Use for**: Translator matrix, OAuth handlers, SSE streaming
- **Location**: `/Users/trongnguyen/code/gh/CLIProxyAPIPlus`
- **Key files**: `sdk/translator/`, `sdk/auth/`, `internal/runtime/executor/`

### LLM-API-Key-Proxy (Python) - Resilience Patterns
- **Use for**: Cooldown strategy, quota groups, credential prioritization
- **Location**: `/Users/trongnguyen/code/gh/LLM-API-Key-Proxy`
- **Key files**: `src/rotator_library/cooldown_manager.py`, `credential_manager.py`

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Feature parity gaps | High | Medium | Incremental migration with proxy pass-through |
| SSE streaming bugs | High | Low | Extensive testing with real providers |
| OAuth complexity | Medium | High | Port Go logic directly, test each provider |
| Performance regression | Medium | Low | Bun is fast; benchmark critical paths |
| Breaking changes | High | Medium | Backward-compatible HTTP API |
| Translation matrix complexity | High | Medium | Allocate 3 weeks, not 2 |

## Success Criteria

1. All existing CLI agents work without modification
2. All 10+ OAuth providers authenticate successfully
3. SSE streaming works reliably for all providers
4. Request latency within 10% of Go implementation
5. Swift app communicates via HTTP (no IPC changes)
6. Fallback chains execute correctly
7. Resilience features match LLM-API-Key-Proxy quality

## Timeline (Revised)

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| 1. Monorepo Setup | 1 week | Workspace structure, CI/CD |
| 2. Server Scaffold | 1 week | Basic HTTP server, health checks, proxy pass-through |
| 3. Core Proxy | 2 weeks | Request routing, SSE, basic translation |
| 4. Auth Handlers | 3 weeks | All 10+ OAuth providers |
| 5. Translation Matrix | **3 weeks** | Full format conversion (6 protocols) |
| 6. Resilience Layer | **1 week** | Cooldowns, rotation, quota groups |
| 7. Management API | 1 week | Complete management endpoints |
| 8. Integration Testing | 2 weeks | E2E tests, bug fixes, migration |
| **Total** | **14 weeks** | |

## Plan Documents

| File | Phase | Description |
|------|-------|-------------|
| `01-monorepo-setup.md` | 1 | Workspace structure, Turborepo config |
| `02-server-architecture.md` | 2-3 | Server scaffold, proxy engine |
| `03-auth-handlers.md` | 4 | OAuth handlers for all providers |
| `04-translation-matrix.md` | 5 | Format conversion between protocols |
| `05-resilience-layer.md` | 6 | Cooldowns, rotation, quota management |
| `06-management-api.md` | 7 | Management endpoints, WebSocket |
| `07-integration-testing.md` | 8 | E2E tests, migration strategy |

## Migration Strategy

### Phase 1: Proxy Pass-through (Week 1-4)
```
Client → quotio-server → CLIProxyAPI (Go binary)
```
- quotio-server acts as transparent proxy
- Allows incremental feature implementation
- Zero risk to existing functionality

### Phase 2: Gradual Takeover (Week 5-10)
```
Client → quotio-server → [Native Handler | CLIProxyAPI fallback]
```
- Implement features one by one
- Fall back to Go binary for unimplemented endpoints
- Feature flags to control rollout

### Phase 3: Full Native (Week 11-14)
```
Client → quotio-server (100% native)
```
- Remove CLIProxyAPI dependency
- Performance optimization
- Production readiness

## Next Steps

1. ✅ Review and approve this plan
2. Begin Phase 1: Monorepo setup
3. Create feature branch `feature/quotio-server`
