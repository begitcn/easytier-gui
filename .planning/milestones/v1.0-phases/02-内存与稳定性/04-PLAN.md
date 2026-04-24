---
wave: 2
depends_on: [02-PLAN, 03-PLAN]
autonomous: true
requirements: [STAB-01, STAB-02]
files_modified:
  - EasyTierGUI/Services/EasyTierService.swift
  - EasyTierGUI/Services/ProcessViewModel.swift
  - EasyTierGUI/EasyTierGUIApp.swift
---

# Plan 2.3: Process Management Robustness

**Goal:** Graceful handling of all process lifecycle events

**Requirements Addressed:**
- STAB-01: 进程管理健壮，异常情况优雅处理
- STAB-02: 应用退出时无孤儿进程残留

## Context

According to decisions:
- D-01: Process crash detection + Toast notification
- D-02: Distinguish and log exit reasons (0=normal, non-0=error, signal=terminated)
- D-03: Graceful termination with timeout (SIGTERM → wait 3s → SIGKILL)
- D-04: Clear cleanup order

## Tasks

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Add process terminationHandler to detect crashes. In start() method after process.run(), add:

```swift
process.terminationHandler = { [weak self] process in
    let exitCode = process.terminationStatus
    let reason = process.terminationReason

    Task { @MainActor [weak self] in
        await self?.handleProcessTermination(exitCode: exitCode, reason: reason)
    }
}
```

**IMPORTANT**: This is the PRIMARY mechanism for detecting process crashes. Without terminationHandler, the app won't know when easytier-core exits unexpectedly.
</action>
<acceptance_criteria>
- [ ] Process has terminationHandler set before run()
- [ ] handler extracts exitCode and terminationReason
- [ ] handler notifies main actor of termination via handleProcessTermination()
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Implement handleProcessTermination() method with D-02 logic. Add this new method to EasyTierService:

```swift
@MainActor
private func handleProcessTermination(exitCode: Int32, reason: Process.TerminationReason) async {
    // Log based on exit reason
    if exitCode == 0 {
        log("Process exited normally", level: .info)
    } else if reason == .uncaughtSignal {
        log("Process terminated by signal: \(exitCode)", level: .warning)
    } else {
        log("Process crashed with exit code: \(exitCode)", level: .error)
        // Notify user via Toast
        showToast?("EasyTier 核心意外退出，请检查日志")
    }

    // Update status
    status = .disconnected
}
```

This method must be created explicitly - it's called by terminationHandler but is not currently implemented.
</action>
<acceptance_criteria>
- [ ] handleProcessTermination() method exists in EasyTierService
- [ ] Logs appropriate level based on exit (info/warning/error)
- [ ] Status updates to .disconnected on any termination
- [ ] Toast shows for non-normal exits
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift (around line 210)
</read_first>
<action>
Implement graceful termination with D-03: SIGTERM → wait 3s → SIGKILL

**CRITICAL FIX**: Current code uses 0.2s delay (usleep(200_000)), need to change to 3 seconds.

Replace the current forceStop() wait logic with:

```swift
func forceStop(allowPrivilegePrompt: Bool = true) {
    guard let pid = currentPID else { return }

    // Step 1: Try graceful termination with SIGTERM
    kill(pid, SIGTERM)

    // Step 2: Wait up to 3 seconds for graceful exit
    var waited = 0
    while waited < 30 {  // 30 * 0.1s = 3 seconds
        usleep(100_000)  // 100ms
        if kill(pid, 0) != 0 {
            // Process exited gracefully
            currentPID = nil
            status = .disconnected
            return
        }
        waited += 1
    }

    // Step 3: Force kill if still running
    kill(pid, SIGKILL)
    currentPID = nil
    status = .disconnected
}
```

**EXACT CODE REQUIRED**: The loop must iterate 30 times with 100ms sleep (30 × 100ms = 3000ms = 3 seconds). Current value of 0.2s is insufficient.
</action>
<acceptance_criteria>
- [ ] forceStop() waits exactly 3 seconds before SIGKILL
- [ ] Uses usleep(100_000) in a 30-iteration loop
- [ ] Graceful SIGTERM is sent first
- [ ] Process either exits cleanly or gets SIGKILL
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/EasyTierGUIApp.swift
</read_first>
<action>
Ensure app termination cleanup follows D-04 order:
1. Stop all running processes
2. Cancel all timers
3. Release subscriptions
4. Close FileHandles

Add applicationWillTerminate that calls ProcessViewModel.forceStopAllSync():
```swift
func applicationWillTerminate(_ notification: Notification) {
    processViewModel.forceStopAllSync(allowPrivilegePrompt: false)
}
```

**NOTE**: Use forceStopAllSync(), not suspendAll() - verify the correct method name is used.
</action>
<acceptance_criteria>
- [ ] applicationWillTerminate calls forceStopAllSync()
- [ ] Pass allowPrivilegePrompt: false to avoid prompts during exit
- [ ] No orphan easytier-core processes after app quit
</acceptance_criteria>
</task>

---

## Verification

Test process crash detection:
1. Start connection successfully
2. Kill easytier-core from terminal: `pkill -f easytier-core`
3. Verify Toast appears with error message
4. Verify status updates to disconnected

Test graceful shutdown:
1. Start connection
2. Force quit app (Cmd+Q)
3. Check `pgrep -f easytier-core` returns empty

---

*Plan: 04-PLAN.md*
*Phase: 02-内存与稳定性*
