# Phase 2: 内存与稳定性 - Research

**Phase:** 02-内存与稳定性
**Purpose:** Plan the implementation of memory stability and resource lifecycle management
**Date:** 2026-04-24

---

## Executive Summary

This document researches the technical patterns required to implement Phase 2: Memory and Stability. The phase addresses 8 requirements (STAB-01, STAB-02, STAB-04, MEM-01 through MEM-05) focused on ensuring long-term memory stability through proper cleanup patterns, robust process management, and correct resource lifecycle handling.

**Key finding:** The codebase already implements several memory management patterns correctly (timer cleanup with `[weak self]`, bounded log buffer at 100 entries, AnyCancellable storage in Set). However, critical gaps exist in process termination handling, exit reason tracking, and process crash detection that need to be implemented.

---

## 1. Technical Research: Swift Memory Management Patterns

### 1.1 Reference Counting Fundamentals

Swift uses Automatic Reference Counting (ARC) for memory management. Key points for this phase:

- **Strong reference cycles** occur when two objects reference each other strongly. Use `[weak self]` or `[unowned self]` in closures to break cycles.
- **Retain cycles** with timers are common because `Timer` holds a strong reference to its target.
- **`deinit` is not actor-isolated** even for `@MainActor` classes. Timer cleanup inside deinit may need to dispatch to main queue for safe invalidation.

### 1.2 Combine Subscription Lifecycle

The current codebase uses the standard pattern for Combine subscription management:

```swift
// Current implementation (correct)
private var cancellables = Set<AnyCancellable>()

init() {
    service.$isRunning
        .receive(on: DispatchQueue.main)
        .sink { [weak self] isRunning in
            self?.status = isRunning ? .connected : .disconnected
        }
        .store(in: &cancellables)
}

deinit {
    cancellables.removeAll()
}
```

**Verification needed:**
- All subscriptions created in `init()` (not in methods that may be called multiple times)
- Confirm `NetworkRuntime` and `ProcessViewModel` follow this pattern consistently

### 1.3 Memory Management Patterns Reference

| Pattern | Implementation | Status in Current Code |
|---------|---------------|------------------------|
| AnyCancellable storage | `Set<AnyCancellable>` | ✅ Implemented in NetworkRuntime and ProcessViewModel |
| Timer weak capture | `[weak self]` in closure | ✅ Implemented in peerTimer |
| Timer invalidation in deinit | `timer?.invalidate()` | ✅ Implemented in NetworkRuntime.deinit |
| Bounded array | Circular buffer with max size | ✅ Implemented (maxLogEntries = 100) |
| FileHandle cleanup | Set handler to nil | ✅ Implemented in stop() methods |

---

## 2. Process Lifecycle Handling in macOS

### 2.1 Process Class and terminationHandler

The `Process` class (Foundation) provides a `terminationHandler` property for observing process exit:

```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/path/to/executable")
process.terminationHandler = { [weak self] process in
    // Called when process exits
    let exitCode = process.terminationStatus
    // Handle termination
}
try process.run()
```

**Requirements for this phase:**
- **STAB-01:** Add `terminationHandler` to detect unexpected process termination
- **STAB-02:** Ensure no orphan processes on app exit - requires proper cleanup in applicationWillTerminate

### 2.2 Graceful Process Termination (SIGTERM → SIGKILL)

The current `forceStop()` method in EasyTierService.swift uses SIGTERM but with insufficient delay:

```swift
// Current implementation (line 209-213)
_kill(pid, SIGTERM)
usleep(200_000)  // Only 0.2 seconds!
if kill(pid, 0) == 0 {
    _kill(pid, SIGKILL)
}
```

**Decision D-03 requires:** SIGTERM → wait 3 seconds → SIGKILL

**Correct implementation pattern:**
```swift
func gracefulStop(pid: Int32) {
    // Step 1: Send SIGTERM (graceful termination request)
    kill(pid, SIGTERM)
    
    // Step 2: Wait up to 3 seconds for process to exit
    var waited = 0
    while waited < 30 {  // 30 * 0.1s = 3s
        usleep(100_000)  // 0.1 second
        if kill(pid, 0) != 0 {
            // Process has exited
            return
        }
        waited += 1
    }
    
    // Step 3: Process didn't exit in time, send SIGKILL
    kill(pid, SIGKILL)
}
```

### 2.3 Exit Reason Tracking

**Decision D-02** requires distinguishing and logging exit reasons:

| Exit Code | Meaning | Log Level |
|-----------|---------|-----------|
| 0 | Normal exit | INFO |
| 1-255 (non-zero) | Error exit | ERROR |
| Signal (negative) | Signal termination | WARN |

```swift
process.terminationHandler = { [weak self] process in
    let status = process.terminationStatus
    let reason = process.terminationReason
    
    if reason == .uncaughtSignal {
        // Process was killed by signal
        let signal = status
        logExitReason(signal: signal, isSignal: true)
    } else if status == 0 {
        logExitReason(exitCode: 0, isNormal: true)
    } else {
        logExitReason(exitCode: status, isError: true)
    }
}
```

---

## 3. Timer and Combine Subscription Cleanup

### 3.1 Timer Best Practices

The current codebase uses `Timer.scheduledTimer` with `[weak self]`:

```swift
// Current implementation (correct)
peerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
    Task { @MainActor in
        self?.fetchPeers()
    }
}
```

**Additional considerations:**
- The timer is stored as an optional property (`peerTimer: Timer?`)
- Invalidated in both `stopPeerPolling()` and `deinit`
- For `@MainActor` classes, `deinit` cannot be actor-isolated, but timer invalidation on main queue is safe

**Potential issue identified:** The `privilegedLogTimer` in EasyTierService.swift should be verified for similar cleanup.

### 3.2 Subscription Leak Prevention

**Pattern for avoiding subscription accumulation:**

1. **Create subscriptions in `init()`** - Not in methods that can be called multiple times
2. **Use `.prefix(1)`** for one-time subscriptions
3. **Store in `Set<AnyCancellable>`** - Allows easy removal

**Verification needed:**
- Confirm no subscriptions are created in view `onAppear` modifiers without proper cleanup
- Check that `ProcessViewModel` subscriptions are all in `init()`

---

## 4. FileHandle Resource Management

### 4.1 Proper FileHandle Cleanup

The current code correctly cleans up FileHandle in `stop()`:

```swift
// EasyTierService.swift line 154-156
outputPipe?.fileHandleForReading.readabilityHandler = nil
outputPipe = nil
```

**Key points:**
- Always set `readabilityHandler = nil` before releasing the pipe
- The handler is a closure that may retain `self` if not cleared
- FileHandle should be nil'd in both normal stop and forceStop paths

### 4.2 Pipe Cleanup Pattern

```swift
func stop() async throws {
    // 1. Clear the readability handler first (breaks retain cycle)
    outputPipe?.fileHandleForReading.readabilityHandler = nil
    
    // 2. Then nil the pipe
    outputPipe = nil
    
    // 3. Continue with process cleanup
    // ...
}
```

---

## 5. Memory Debugging Techniques

### 5.1 Xcode Memory Graph Debugger

**When to use:**
- After implementing cleanup code
- To verify no memory leaks exist during connect/disconnect cycles

**How to use:**
1. Run app in Debug mode
2. Pause execution at a breakpoint
3. Click "Debug Memory Graph" in the debug navigator
4. Look for cycles (purple dots) and leaks (red dots)

**Automated verification (Decision D-05):**
- Create a script that runs the app, performs connect/disconnect cycles, and captures memory graph
- Compare object counts before and after

### 5.2 Instruments Allocations

**When to use:**
- Monitor memory growth over time
- Identify growing allocations (potential leaks)

**How to use:**
1. Product → Profile → Allocations
2. Record while performing repeated connect/disconnect cycles
3. Check "Growth" column for steadily increasing allocations

**Automation (Decision D-06):**
- Use command-line Instruments: `xcrun instruments -t Allocations`
- Parse results to detect linear memory growth

### 5.3 Code Assertions for Debugging

**Decision D-07** suggests adding debug assertions:

```swift
#if DEBUG
deinit {
    // Debug logging to verify deinit is called
    print("[DEBUG] NetworkRuntime deinit - id: \(id)")
    
    // Assert timer is nil (should be cleaned up)
    assert(peerTimer == nil, "Timer not invalidated before deinit")
}
#endif
```

---

## 6. Validation Architecture for Nyquist Validation

### 6.1 Validation Framework

The project uses a validation system (likely for testing). This section defines how to validate Phase 2 implementations.

### 6.2 Test Scenarios

| Test ID | Scenario | Expected Result |
|---------|----------|-----------------|
| V-STAB-01 | Start connection, crash process externally | Toast notification appears, status updates |
| V-STAB-02 | App quit while connected | No orphan easytier-core processes |
| V-STAB-04 | Generate 1000+ log messages | App remains stable, no crash |
| V-MEM-01 | Run app for 1 hour | Memory stable, no growth |
| V-MEM-02 | Verify log buffer | Never exceeds 100 entries |
| V-MEM-03 | Check subscription count | Cancellables Set count stable |
| V-MEM-04 | Verify timer cleanup | No timers firing after disconnect |
| V-MEM-05 | Check FileHandle | No unclosed handles in Activity Monitor |

### 6.3 Automated Validation Script

```bash
# V-STAB-02: Check for orphan processes after quit
function test_no_orphans() {
    # Start app, connect, quit
    open EasyTierGUI.app
    sleep 2
    
    # Check for orphan processes
    ORPHANS=$(pgrep -f "easytier-core" | wc -l)
    if [ "$ORPHANS" -gt 0 ]; then
        echo "FAIL: Found $ORPHANS orphan processes"
        return 1
    fi
    echo "PASS: No orphan processes"
    return 0
}

# V-MEM-01: Memory stability test
function test_memory_stability() {
    # Run for 5 minutes with repeated operations
    # Monitor RSS memory via ps
    # Verify no linear growth
}
```

### 6.4 Manual Verification Checklist

- [ ] **Process crash detection:** Kill easytier-core externally, verify Toast appears
- [ ] **Graceful shutdown:** Observe SIGTERM → wait → SIGKILL behavior in logs
- [ ] **Exit reason logging:** Check console for exit reason messages
- [ ] **Timer cleanup:** Add debug logging to timer callback, verify not called after disconnect
- [ ] **deinit logging:** Enable debug logs, verify NetworkRuntime deinit is called on disconnect

---

## 7. Implementation Checklist

Based on research, the following implementation tasks are required:

### 7.1 Process Termination Handling (STAB-01)

- [ ] Add `terminationHandler` to Process objects in EasyTierService.start()
- [ ] Implement process crash detection with status update
- [ ] Integrate with existing Toast mechanism for notification

### 7.2 Exit Reason Tracking (D-02)

- [ ] Add logging for exit codes: 0 = INFO, non-0 = ERROR, signal = WARN
- [ ] Distinguish between normal exit and error exit

### 7.3 Graceful Termination (D-03, STAB-02)

- [ ] Modify forceStop() to use 3-second timeout before SIGKILL
- [ ] Implement proper signal handling sequence

### 7.4 Resource Cleanup Order (D-04)

- [ ] Define clear cleanup order: stop process → cancel timers → release subscriptions → close FileHandle
- [ ] Apply in both normal stop and forceStop paths
- [ ] Ensure app termination also follows this order

### 7.5 Debug Logging (D-09)

- [ ] Add deinit logging to NetworkRuntime
- [ ] Add deinit logging to EasyTierService (if applicable)
- [ ] Wrap in #if DEBUG for production

### 7.6 Memory Verification (D-05, D-06, D-08)

- [ ] Document Memory Graph Debugger usage
- [ ] Document Instruments Allocations usage
- [ ] Create automated test script for connect/disconnect cycles

---

## 8. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Timer not invalidated on all paths | Memory leak, crashes | Review all code paths that could lead to deinit without stop |
| Process not terminated on app quit | Orphan processes | Implement applicationWillTerminate cleanup |
| Exit handler not called for privileged processes | Missed crash detection | Add fallback detection via polling privilegedPID |
| Main thread blocking during graceful stop | UI freeze | Use async/await with background queue |

---

## 9. References

### 9.1 Apple Documentation

- [Process - Foundation | Apple Developer](https://developer.apple.com/documentation/foundation/process)
- [Timer - Foundation | Apple Developer](https://developer.apple.com/documentation/foundation/timer)
- [AnyCancellable | Apple Developer](https://developer.apple.com/documentation/combine/anycancellable)
- [Memory Graph Debugger | Xcode Help](https://help.apple.com/xcode/mac/9.0/#/devfc8d96972)

### 9.2 Codebase References

- `EasyTierService.swift` - Process management, forceStop(), FileHandle cleanup
- `ProcessViewModel.swift` - NetworkRuntime with Timer and Combine subscriptions
- `ToastView.swift` - Toast notification mechanism (Phase 1)
- `.planning/phases/01-响应性与交互反馈/01-CONTEXT.md` - Previous phase decisions

### 9.3 Research Sources

- `.planning/research/SUMMARY.md` - Project research summary
- `.planning/research/PITFALLS.md` - Common pitfalls including timer retain cycles
- `.planning/research/ARCHITECTURE.md` - Architecture patterns including Timer lifecycle

---

*Research completed: 2026-04-24*
*Ready for planning: Yes*
