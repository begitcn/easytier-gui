---
wave: 2
depends_on: [02-PLAN, 03-PLAN]
autonomous: true
requirements: [MEM-05]
files_modified:
  - EasyTierGUI/Services/EasyTierService.swift
---

# Plan 2.4: FileHandle & Resource Cleanup

**Goal:** No leaked file handles or pipes

**Requirements Addressed:**
- MEM-05: FileHandle 正确关闭，无资源泄漏

## Context

Current implementation in EasyTierService.swift:
- Sets readabilityHandler to nil before releasing pipe
- Need to verify cleanup is called on all paths
- Need to ensure proper cleanup order (D-04)

## Tasks

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Audit all FileHandle and Pipe usage. Search for:
- Process.stdout, Process.stderr
- Pipe() creations
- readabilityHandler assignments

Verify each has corresponding cleanup in stop() method
</action>
<acceptance_criteria>
- [ ] All Pipe instances have handler = nil before being set to nil
- [ ] stop() cleans up both outputPipe and errorPipe (if any)
- [ ] forceStop() also performs cleanup
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Verify cleanup order in stop() method follows D-04:
1. Clear readabilityHandler first (breaks retain cycle)
2. Set pipe to nil
3. Continue with process cleanup

```swift
func stop() async throws {
    // 1. Clear readability handler first
    outputPipe?.fileHandleForReading.readabilityHandler = nil
    outputPipe = nil

    // 2. Terminate process if running
    if let pid = currentPID, kill(pid, 0) == 0 {
        gracefulStop(pid: pid)
    }

    // 3. Clear process reference
    process = nil
}
```
</action>
<acceptance_criteria>
- [ ] readabilityHandler is set to nil before pipe is set to nil
- [ ] Both normal stop and forceStop follow same cleanup order
- [ ] No retain cycles between self and handler closure
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Add debug assertions to verify resource cleanup in debug builds. Add to EasyTierService:

```swift
#if DEBUG
// Add debug assertions after cleanup in stop() or forceStop()
private func verifyCleanup() {
    assert(outputPipe == nil, "outputPipe not cleaned up!")
    assert(process == nil, "process not cleaned up!")
    print("[DEBUG] EasyTierService cleanup verified - config: \(config.name)")
}
#endif
```

Call verifyCleanup() at the end of stop() and forceStop() in debug builds.

**IMPORTANT**: These debug assertions are required to catch resource leaks during development. Without them, cleanup issues may go unnoticed.
</action>
<acceptance_criteria>
- [ ] Debug builds have assertions that verify outputPipe == nil
- [ ] Debug builds have assertions that verify process == nil
- [ ] Console shows cleanup verification messages
- [ ] Debug assertions trigger if cleanup is incomplete
</acceptance_criteria>
</task>

---

## Verification

Check for open file handles using lsof:
1. Run app, connect
2. Open Terminal: `lsof -p $(pgrep EasyTierGUI)` 
3. Check for easytier-core pipes
4. Disconnect
5. Verify no pipe handles remain open

---

*Plan: 05-PLAN.md*
*Phase: 02-内存与稳定性*
