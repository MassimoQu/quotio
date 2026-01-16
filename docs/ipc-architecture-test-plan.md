# IPC Architecture Refactoring - Test Plan

**Created:** 2026-01-16
**Related:** [IPC Architecture Refactoring Prompt](./ipc-architecture-refactoring-prompt.md)
**Status:** Ready for Manual Testing

## Overview

This document outlines the test plan for validating the IPC Architecture Refactoring changes. All tests require manual execution on macOS.

## Prerequisites

- macOS 15.0+ (Sequoia)
- Xcode 16+ installed
- quotio-cli daemon available (`bun run dev:daemon` or installed globally)
- Build the app: `xcodebuild -project Quotio.xcodeproj -scheme Quotio -configuration Debug build`

## Test Environment Setup

```bash
# Terminal 1: Watch daemon logs
cd quotio-cli && bun run dev:daemon

# Terminal 2: Watch Swift logs (after launching app)
log stream --predicate 'subsystem == "com.quotio.app"' --level debug

# Alternative: Use Console.app and filter for "[DaemonIPCClient]" or "[DaemonManager]"
```

## Test Cases

### TC-01: Cold Start

**Scenario:** App launches when daemon is not running, then daemon starts.

**Preconditions:**
- Daemon is NOT running
- App is NOT running

**Steps:**
1. Ensure daemon is stopped: `pkill -f "quotio daemon"` or `pkill bun`
2. Launch Quotio app from Xcode (`Cmd + R`)
3. Observe UI shows "Daemon IPC: Inactive" or similar
4. Start daemon: `cd quotio-cli && bun run dev:daemon`
5. Wait up to 10 seconds for health check

**Expected Results:**
- [ ] App launches without crash
- [ ] UI initially shows daemon as inactive/disconnected
- [ ] After daemon starts, UI updates to "Active" within 10 seconds
- [ ] Console logs show: `[DaemonIPCClient] Connected to daemon`

**Actual Results:** _To be filled during testing_

---

### TC-02: External Daemon (Pre-existing)

**Scenario:** Daemon is already running when app launches.

**Preconditions:**
- Daemon IS running
- App is NOT running

**Steps:**
1. Start daemon first: `cd quotio-cli && bun run dev:daemon`
2. Verify daemon responds: `echo '{"jsonrpc":"2.0","id":1,"method":"daemon.ping","params":{}}' | nc -U ~/Library/Caches/quotio-cli/quotio.sock`
3. Launch Quotio app from Xcode
4. Observe UI immediately

**Expected Results:**
- [ ] App detects running daemon within 2 seconds
- [ ] UI shows "Active" status immediately (no flicker to inactive)
- [ ] `daemon.ping` call succeeds
- [ ] Console logs show successful connection

**Actual Results:** _To be filled during testing_

---

### TC-03: Daemon Restart (Auto-Reconnect)

**Scenario:** Daemon stops while app is running, then restarts.

**Preconditions:**
- Daemon IS running
- App IS running and showing "Active"

**Steps:**
1. With both running and showing "Active"
2. Stop daemon: `pkill -f "quotio daemon"` or `Ctrl+C` in daemon terminal
3. Observe UI changes to "Inactive" within 10 seconds
4. Wait 5 seconds
5. Restart daemon: `cd quotio-cli && bun run dev:daemon`
6. Observe UI recovery

**Expected Results:**
- [ ] UI shows "Inactive" after daemon stops (within 10s health check interval)
- [ ] Console logs show: `[DaemonManager] Health check failed`
- [ ] After daemon restarts, UI recovers to "Active" within 10 seconds
- [ ] Console logs show: `[DaemonIPCClient] Connected to daemon`
- [ ] No crash or hang occurs

**Actual Results:** _To be filled during testing_

---

### TC-04: Concurrent Requests

**Scenario:** Multiple IPC calls are made simultaneously.

**Preconditions:**
- Daemon IS running
- App IS running and showing "Active"

**Steps:**
1. Navigate through app rapidly, triggering multiple IPC calls:
   - Open Dashboard (triggers status fetch)
   - Open Providers (triggers auth.list)
   - Open Logs (triggers logs.fetch)
   - Open API Keys (triggers apiKeys.list)
2. Repeat navigation rapidly 5 times
3. Check Console.app for any errors

**Expected Results:**
- [ ] All navigation succeeds without error
- [ ] No "request timeout" errors
- [ ] No "pending request not found" errors
- [ ] UI data loads correctly for each screen
- [ ] Console logs show matched request/response pairs (same IDs)

**Actual Results:** _To be filled during testing_

---

### TC-05: Socket Not Found

**Scenario:** Daemon socket file doesn't exist.

**Preconditions:**
- Daemon is NOT running
- Socket file does NOT exist

**Steps:**
1. Stop daemon if running
2. Remove socket file: `rm -f ~/Library/Caches/quotio-cli/quotio.sock`
3. Launch Quotio app
4. Observe error handling

**Expected Results:**
- [ ] App launches without crash
- [ ] UI shows clear "Daemon not running" or "Inactive" message
- [ ] Console logs show: `[DaemonIPCClient] Socket not found`
- [ ] User is offered option to start daemon (if implemented)
- [ ] No infinite retry loops (check CPU usage)

**Actual Results:** _To be filled during testing_

---

## Regression Tests

### RT-01: OAuth Flow

**Scenario:** Verify OAuth still works after IPC refactoring.

**Steps:**
1. Go to Providers tab
2. Click on a provider (e.g., Gemini)
3. Click "Add Account" / "Login"
4. Complete OAuth in browser
5. Verify account appears in list

**Expected Results:**
- [ ] OAuth flow completes successfully
- [ ] Account appears in provider list
- [ ] Quota information loads

---

### RT-02: Proxy Start/Stop

**Scenario:** Verify proxy lifecycle management still works.

**Steps:**
1. Go to Dashboard
2. Click "Start" to start proxy
3. Verify proxy status shows "Running"
4. Click "Stop" to stop proxy
5. Verify proxy status shows "Stopped"

**Expected Results:**
- [ ] Proxy starts without errors
- [ ] Proxy stops without errors
- [ ] Status updates correctly in UI

---

### RT-03: API Key Management

**Scenario:** Verify API key CRUD operations work.

**Steps:**
1. Go to API Keys tab
2. Create a new API key
3. Copy the key
4. Delete the key

**Expected Results:**
- [ ] Key creation succeeds
- [ ] Key appears in list
- [ ] Key deletion succeeds
- [ ] Key disappears from list

---

## Performance Tests

### PT-01: Memory Stability

**Steps:**
1. Launch app with daemon running
2. Use Activity Monitor to note initial memory usage
3. Navigate through all tabs repeatedly for 5 minutes
4. Check memory usage again

**Expected Results:**
- [ ] Memory increase < 50MB over baseline
- [ ] No memory leaks visible

---

### PT-02: Connection Stability

**Steps:**
1. Leave app running with daemon for 1 hour
2. Periodically check UI shows "Active"
3. Check Console.app for any connection errors

**Expected Results:**
- [ ] Connection remains stable for 1 hour
- [ ] No spurious disconnections
- [ ] Health check continues working

---

## Debugging Guide

### Common Issues

| Symptom | Check | Solution |
|---------|-------|----------|
| "Inactive" despite daemon running | Console: `[DaemonIPCClient]` logs | Check socket path matches |
| Requests timeout | Console: pending request logs | Check daemon is processing requests |
| Rapid connect/disconnect | Console: connection events | Check for retry loops |
| UI doesn't update | Check `@MainActor` annotations | Ensure state updates on main thread |

### Log Filters for Console.app

```
# All IPC client logs
predicate: message CONTAINS "[DaemonIPCClient]"

# All daemon manager logs
predicate: message CONTAINS "[DaemonManager]"

# Connection events only
predicate: message CONTAINS "Connected" OR message CONTAINS "Disconnected"

# Errors only
predicate: message CONTAINS "Error" OR message CONTAINS "failed"
```

### Manual Socket Test

```bash
# Test daemon is responding
echo '{"jsonrpc":"2.0","id":1,"method":"daemon.ping","params":{}}' | nc -U ~/Library/Caches/quotio-cli/quotio.sock

# Expected response:
# {"jsonrpc":"2.0","id":1,"result":{"success":true,"message":"pong"}}
```

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Developer | | | |
| Tester | | | |
| Reviewer | | | |

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-16 | AI Assistant | Initial test plan |
