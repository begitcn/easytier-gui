---
wave: 1
depends_on: []
autonomous: true
requirements: [MEM-03]
files_modified:
  - EasyTierGUI/Services/ProcessViewModel.swift
---

# Plan 2.1: Combine Subscription Management

**Goal:** Ensure all Combine subscriptions are properly managed with no leaks

**Requirements Addressed:**
- MEM-03: Combine 订阅正确管理，无遗留订阅

## Context

The codebase already uses `Set<AnyCancellable>` pattern, but we need to verify:
1. All subscriptions are created in `init()`, not in methods called multiple times
2. All subscriptions are stored in the cancellables set
3. Critical subscriptions have explicit cancel in `deinit`

## Tasks

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Audit all AnyCancellable storage locations in ProcessViewModel.swift. Verify:
- NetworkRuntime.cancellables is a Set<AnyCancellable>
- All subscriptions use .store(in: &cancellables)
- No subscriptions created in onAppear or similar repeated methods
</action>
<acceptance_criteria>
- [ ] NetworkRuntime has `private var cancellables = Set<AnyCancellable>()`
- [ ] All .sink() and .assign() calls use .store(in: &cancellables)
- [ ] No subscriptions created in body, onAppear, or other repeated methods
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Add explicit cancel and debug logging in NetworkRuntime deinit. Add this at the end of the NetworkRuntime class:

```swift
#if DEBUG
deinit {
    print("[DEBUG] NetworkRuntime deinit - id: \(id)")
}
#endif
cancellables.removeAll()
```

**IMPORTANT**: This debug logging is required to verify the NetworkRuntime is actually being deallocated. Without it, we cannot confirm there are no retain cycles.
</action>
<acceptance_criteria>
- [ ] NetworkRuntime has deinit that removes all cancellables
- [ ] Debug build prints deinit message with runtime id
- [ ] Console shows "[DEBUG] NetworkRuntime deinit" when runtime stops
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Verify ProcessViewModel.forceStopAllSync() properly cancels all subscriptions before cleanup. This method is called during app termination to stop all network runtimes.

**NOTE**: The method is named `forceStopAllSync()`, not `suspendAll()`. Ensure the call in applicationWillTerminate uses the correct method name.
</action>
<acceptance_criteria>
- [ ] forceStopAllSync() iterates all runtimes and calls stop()
- [ ] No subscriptions leak when runtimes are removed
- [ ] applicationWillTerminate calls forceStopAllSync() (not suspendAll)
</acceptance_criteria>
</task>

---

## Verification

Run Memory Graph Debugger after repeated connect/disconnect cycles:
1. Run app in Debug mode
2. Connect, wait 5 seconds, disconnect
3. Repeat 10 times
4. Open Memory Graph Debugger
5. Verify no orphaned AnyCancellable objects
6. Verify console shows "[DEBUG] NetworkRuntime deinit" messages

---

*Plan: 02-PLAN.md*
*Phase: 02-内存与稳定性*
