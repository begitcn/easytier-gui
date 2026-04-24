---
wave: 1
depends_on: []
autonomous: true
requirements: [MEM-04]
files_modified:
  - EasyTierGUI/Services/ProcessViewModel.swift
  - EasyTierGUI/Services/EasyTierService.swift
---

# Plan 2.2: Timer Lifecycle Management

**Goal:** Ensure all timers are properly invalidated with no retain cycles

**Requirements Addressed:**
- MEM-04: Timer 正确清理，无循环引用

## Context

The codebase already uses `[weak self]` in timer closures, but need to verify:
1. All timers are invalidated in both stop() and deinit
2. Timer cleanup is called on all code paths
3. No timers fire after disconnect

## Tasks

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift (NetworkRuntime class)
</read_first>
<action>
Verify peerTimer cleanup in NetworkRuntime. Check:
- peerTimer is declared as optional: `private var peerTimer: Timer?`
- startPeerPolling() uses [weak self] in closure
- stopPeerPolling() calls invalidate() and sets nil
- deinit also invalidates timer
</action>
<acceptance_criteria>
- [ ] peerTimer uses `[weak self]` in Timer.scheduledTimer closure
- [ ] stopPeerPolling() calls `peerTimer?.invalidate(); peerTimer = nil`
- [ ] deinit has `peerTimer?.invalidate()` for safety
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
**Add EasyTierService deinit** for timer cleanup. Add at the end of EasyTierService class:

```swift
#if DEBUG
deinit {
    print("[DEBUG] EasyTierService deinit - config: \(config.name)")
}
#endif

deinit {
    // Clean up timer if still running
    privilegedLogTimer?.invalidate()
}
```

**IMPORTANT**: EasyTierService also has timers (privilegedLogTimer) that need explicit cleanup in deinit. This is a safety net in case stop() is never called.
</action>
<acceptance_criteria>
- [ ] EasyTierService has deinit that invalidates privilegedLogTimer
- [ ] Debug builds print deinit message with config name
- [ ] Timer is cleaned up even if stop() is not called
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Verify the cleanup order in stop() method follows D-04:
1. Stop process
2. Cancel timers
3. Release subscriptions
4. Close FileHandle

Add debug logging to verify timer invalidation happens:
```swift
func stopPeerPolling() {
    peerTimer?.invalidate()
    peerTimer = nil
    #if DEBUG
    print("[DEBUG] Timer invalidated for runtime: \(id)")
    #endif
}
```

**IMPORTANT**: Timer invalidation debug logging is required to verify timers are being cleaned up properly.
</action>
<acceptance_criteria>
- [ ] stop() method follows cleanup order: process → timer → subscription → filehandle
- [ ] Debug logs show timer invalidation messages with runtime id
- [ ] Console shows "[DEBUG] Timer invalidated" when disconnecting
</acceptance_criteria>
</task>

---

## Verification

Test timer cleanup by adding debug output:
1. Connect and wait for peer polling to start
2. Disconnect
3. Check console for "Timer invalidated" messages
4. Wait 10 seconds, verify no more peer fetch attempts

---

*Plan: 03-PLAN.md*
*Phase: 02-内存与稳定性*
