---
wave: 5
depends_on:
  - 04-PLAN.md
files_modified:
  - EasyTierGUI/Services/EasyTierService.swift
autonomous: true
requirements:
  - PERF-04
---

# Plan 1.5: Log View Performance Optimization

**Goal:** Ensure smooth scrolling even with rapid log updates by verifying existing bounded buffer and adding throttling for UI updates.

## Problem Statement

Log view could potentially have performance issues with rapid log output. Need to verify the circular buffer implementation is working correctly and add UI update throttling to prevent excessive re-renders.

## Current State

- ✅ `LogEntry` already conforms to `Identifiable` (Models.swift:169)
- ✅ `LogView` already uses `LazyVStack` (LogView.swift:129)
- ✅ `maxLogEntries = 100` is defined (EasyTierService.swift:65)
- ✅ Circular buffer removes old entries (EasyTierService.swift:388-390)
- ✅ Auto-scroll to bottom is implemented (LogView.swift:138-144)

## Remaining Work

Add throttling to prevent excessive UI updates from rapid log output.

## Tasks

### Task 1: Add log update throttling

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/EasyTierService.swift
</read_first>

<action>
Add a throttle mechanism to prevent excessive UI updates from rapid log output. Add properties and modify the `parseLogEntries` method:

Add new properties after line 66 (`private let maxLogMessageLength = 2000`):
```swift
// MARK: - Log Update Throttling

private var logUpdateTask: Task<Void, Never>?
private let logUpdateThrottleInterval: TimeInterval = 0.1 // 100ms
private var pendingLogLines: [String] = []
private let pendingLogLock = NSLock()
```

Replace the `parseLogEntries` method (lines 369-391) with a throttled version:

```swift
/// 解析日志条目
private func parseLogEntries(_ text: String) {
    guard isLogMonitoringEnabled else {
        pendingLogFragment = ""
        return
    }

    let combined = pendingLogFragment + text
    let hasTrailingNewline = combined.unicodeScalars.last.map { CharacterSet.newlines.contains($0) } ?? false
    var lines = combined.components(separatedBy: .newlines)
    if !hasTrailingNewline, !lines.isEmpty {
        pendingLogFragment = lines.removeLast()
    } else {
        pendingLogFragment = ""
    }

    // Add lines to pending queue
    pendingLogLock.lock()
    for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
        pendingLogLines.append(line)
    }
    pendingLogLock.unlock()

    // Throttle UI update
    scheduleLogUpdate()
}

private func scheduleLogUpdate() {
    logUpdateTask?.cancel()
    logUpdateTask = Task {
        try? await Task.sleep(nanoseconds: UInt64(logUpdateThrottleInterval * 1_000_000_000))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.flushPendingLogs()
        }
    }
}

@MainActor
private func flushPendingLogs() {
    pendingLogLock.lock()
    let linesToProcess = pendingLogLines
    pendingLogLines.removeAll()
    pendingLogLock.unlock()

    for line in linesToProcess {
        logEntries.append(parseLogLine(line))
    }

    if logEntries.count > maxLogEntries {
        logEntries.removeFirst(logEntries.count - maxLogEntries)
    }
}
```

This batches log updates every 100ms instead of updating on every line, reducing UI re-renders during rapid log output.
</action>

<acceptance_criteria>
- `EasyTierService` has `logUpdateThrottleInterval = 0.1` (100ms)
- `EasyTierService` has `pendingLogLines` array and `pendingLogLock` for thread safety
- `parseLogEntries` uses `scheduleLogUpdate()` for throttled updates
- `flushPendingLogs()` batches multiple lines into single UI update
- Log updates are dispatched to MainActor
</acceptance_criteria>

---

## Verification

1. Build and run the application
2. Start a network connection with verbose logging
3. Verify log view scrolls smoothly even with rapid output
4. Verify no frame drops when many logs arrive quickly
5. Use Instruments to verify no main thread stalls during log updates
6. Verify memory stays stable (bounded at 100 entries per network)

## must_haves

- [x] `maxLogEntries = 100` is enforced (already verified)
- [x] Log updates are throttled (100ms batches)
- [x] No main thread blocking during log parsing
- [x] Memory bounded with circular buffer (already verified)
- [x] `LazyVStack` used for efficient rendering (already verified)
