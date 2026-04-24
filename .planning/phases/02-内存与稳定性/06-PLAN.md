---
wave: 3
depends_on: [02-PLAN, 03-PLAN, 04-PLAN, 05-PLAN]
autonomous: false
requirements: [STAB-04, MEM-01, MEM-02]
files_modified: []
---

# Plan 2.5: Memory Stability Testing

**Goal:** Validate memory stability over extended use

**Requirements Addressed:**
- STAB-04: 大量日志不影响应用稳定性
- MEM-01: 长时间运行内存稳定，无明显泄漏
- MEM-02: 日志缓冲区大小可控（maxLogEntries = 100 已实现）

## Context

Memory stability verification requires:
- Manual testing with Memory Graph Debugger
- Instruments Allocations for growth trends
- Automated connect/disconnect cycle testing
- Log buffer verification

Note: MEM-02 (maxLogEntries = 100) is already implemented per 02-RESEARCH.md

## Tasks

<task>
<read_first>
- EasyTierGUI/Models/Models.swift
</read_first>
<action>
Verify log buffer implementation. Check LogEntry array:
- Should have max size limit (100 entries)
- Should use circular buffer or similar
- Verify limit is enforced on rapid log output
</action>
<acceptance_criteria>
- [ ] LogEntry array has .prefix(100) or similar limit
- [ ] Array does not grow beyond limit
- [ ] Old entries removed when limit reached
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Manual memory test with Xcode Memory Graph Debugger:

1. Run app in Debug mode (Cmd+R)
2. Perform connect → wait 5s → disconnect cycle 10 times
3. Pause app (Cmd+.)
4. Open Debug Navigator → click "Memory Graph"
5. Search for leaked objects:
   - AnyCancellable instances
   - Timer instances
   - EasyTierService instances
   - NetworkRuntime instances
6. Check console for "[DEBUG] NetworkRuntime deinit" messages to confirm deallocation
</action>
<acceptance_criteria>
- [ ] No AnyCancellable leaks after disconnect cycles
- [ ] No Timer leaks (peerTimer should be nil)
- [ ] EasyTierService deallocates after stop
- [ ] NetworkRuntime deallocates after disconnect (check console)
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift
</read_first>
<action>
Run Instruments Allocations to detect memory growth:

1. Product → Profile → Allocations
2. Record while performing:
   - Connect, wait 5s, disconnect (repeat 20 times)
3. Review "Growth" column
4. Check heap for steadily increasing allocations
</action>
<acceptance_criteria>
- [ ] No linear growth in total allocations
- [ ] Heap shows stable object counts after each cycle
- [ ] Memory returns to baseline after disconnect
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/Services/EasyTierService.swift
</read_first>
<action>
Test stability with rapid log output:

1. Connect to network with high verbosity
2. Generate 500+ log entries rapidly
3. Verify:
   - UI remains responsive
   - No crashes
   - Log buffer stays at ~100 entries
   - Memory doesn't spike
</action>
<acceptance_criteria>
- [ ] App remains responsive with 500+ log entries
- [ ] No crashes during rapid logging
- [ ] Memory stays within acceptable bounds (<100MB)
</acceptance_criteria>
</task>

<task>
<read_first>
- EasyTierGUI/EasyTierGUIApp.swift
</read_first>
<action>
Document Memory Graph Debugger usage for Phase 3 preparation. Create notes:
- When to use (after connect/disconnect cycles)
- What to look for (purple cycles, red leaks)
- Common patterns to verify (timers, subscriptions, handles)

This prepares for Phase 3 memory warning handling
</action>
<acceptance_criteria>
- [ ] Documentation explains how to detect memory leaks
- [ ] Lists key object types to check
- [ ] Identifies acceptable vs concerning object counts
</acceptance_criteria>
</task>

---

## Verification

Final validation checklist:
- [ ] Memory Graph shows no leaks after 10 connect/disconnect cycles
- [ ] Instruments shows no linear memory growth over 20 cycles
- [ ] Rapid logging (500+ entries) doesn't crash or freeze app
- [ ] Log buffer capped at 100 entries
- [ ] All timers, subscriptions, handles cleaned up
- [ ] Console shows "[DEBUG] NetworkRuntime deinit" messages confirming cleanup

---

*Plan: 06-PLAN.md*
*Phase: 02-内存与稳定性*
