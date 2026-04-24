# Roadmap: EasyTier GUI Performance Optimization

**Created:** 2025-04-24
**Mode:** yolo
**Granularity:** standard
**Core Value:** 程序稳定运行，交互响应及时，内存长期稳定

## Overview

Three-phase optimization approach for EasyTier GUI, a native macOS SwiftUI application providing graphical interface for EasyTier P2P VPN. This roadmap focuses on performance, stability, interaction feedback, memory management, and UI polish—no new features.

**Total v1 Requirements:** 24
**Phases:** 3
**Estimated Timeline:** 3-4 weeks

---

## Phase 1: 响应性与交互反馈

**Focus:** Performance + Interaction
**Duration:** ~1.5 weeks
**Risk:** MEDIUM

### Objective

Eliminate main thread blocking, establish responsive UI patterns, and implement comprehensive interaction feedback. Users should never see a spinning beach ball, and every action should provide immediate visual acknowledgment.

### Requirements Coverage

| ID | Description |
|----|-------------|
| PERF-01 | 启动时间 < 1 秒，无明显卡顿 |
| PERF-02 | 连接/断开操作无 spinning beach ball |
| PERF-03 | 所有耗时操作在后台队列执行，主线程保持响应 |
| PERF-04 | 日志滚动流畅，无卡顿 |
| STAB-03 | 权限错误有明确提示和处理 |
| INT-01 | 连接按钮点击后立即显示加载状态 |
| INT-02 | 断开按钮点击后立即显示加载状态 |
| INT-03 | 操作成功有明确提示（Toast/成功图标） |
| INT-04 | 操作失败有明确提示（错误 Alert，用户友好） |
| INT-05 | 加载状态清晰可见（ProgressView + 按钮禁用） |
| INT-06 | 错误信息用户友好，可理解，非技术性 |

### Success Criteria

1. **No Beach Balls:** User can interact with UI at all times; connect/disconnect operations never block the main thread
2. **Immediate Feedback:** Every button click shows visual response within 100ms (loading spinner, disabled state, or progress indicator)
3. **Clear Error Communication:** All error conditions display user-friendly messages with actionable guidance (no raw error codes or stack traces)
4. **Smooth Log Scrolling:** Log view scrolls smoothly even with rapid log output; no frame drops during updates
5. **Fast Startup:** App shows main window and becomes interactive within 1 second of launch

### Plans

#### Plan 1.1: Startup Optimization

**Goal:** Achieve < 1s startup with responsive UI immediately

**Tasks:**
1. Profile `AppDelegate.applicationDidFinishLaunching` for blocking operations
2. Move core initialization to background queue with `Task.detached`
3. Show placeholder UI during initialization, update when ready
4. Defer non-critical setup (update check, telemetry) to post-launch
5. Add Instruments Time Profiler baseline measurement

**Pitfalls:**
- MainActor isolation on ViewModels requires careful async handoff
- Don't use `DispatchQueue.main.async` inside `@MainActor` methods—redundant

#### Plan 1.2: Connect/Disconnect Responsiveness

**Goal:** Zero main thread blocking during network operations

**Tasks:**
1. Audit `EasyTierService.start()` for synchronous operations
2. Wrap `PrivilegedExecutor.runCommand()` in `withCheckedThrowingContinuation`
3. Move process spawning to background queue
4. Implement async state machine for connection lifecycle
5. Add timeout handling with user notification

**Pitfalls:**
- Authorization Services dialog is OS-modal but shouldn't block app
- Never call `Process.run()` directly from UI code

#### Plan 1.3: Loading States & Visual Feedback

**Goal:** Every action shows immediate visual acknowledgment

**Tasks:**
1. Add `isLoading` state to `NetworkRuntime` for each operation
2. Update `ConnectionView` buttons to show `ProgressView` during operations
3. Disable interactive elements during loading states
4. Add status text updates ("Connecting...", "Disconnecting...")
5. Implement optimistic UI updates where safe

**Key Patterns:**
- `@Published var isConnecting: Bool` in NetworkRuntime
- Button with `disabled(runtime.isConnecting)` modifier

#### Plan 1.4: Error Handling & User Feedback

**Goal:** All errors have user-friendly messages with clear actions

**Tasks:**
1. Create `UserFacingError` protocol for error message transformation
2. Map common error types to user-friendly descriptions
3. Implement Toast notification system for transient feedback
4. Add Alert system for critical errors requiring user action
5. Include recovery suggestions in error messages

**Error Categories:**
- Permission denied → "需要管理员权限来创建网络设备"
- Process crashed → "EasyTier 核心意外退出，请检查日志"
- Network timeout → "连接超时，请检查网络设置"

#### Plan 1.5: Log View Performance

**Goal:** Smooth scrolling even with rapid log updates

**Tasks:**
1. Verify circular buffer implementation (`maxLogEntries = 100`)
2. Implement batch updates with throttle (debounce rapid updates)
3. Use `LazyVStack` for log entry rendering
4. Add scroll-to-bottom toggle with smooth animation
5. Profile with Instruments for frame drops

---

## Phase 2: 内存与稳定性

**Focus:** Memory + Stability
**Duration:** ~1 week
**Risk:** LOW

### Objective

Ensure long-term memory stability through proper cleanup patterns, robust process management, and correct resource lifecycle handling. The app should run indefinitely without memory growth or resource leaks.

### Requirements Coverage

| ID | Description |
|----|-------------|
| STAB-01 | 进程管理健壮，异常情况优雅处理 |
| STAB-02 | 应用退出时无孤儿进程残留 |
| STAB-04 | 大量日志不影响应用稳定性 |
| MEM-01 | 长时间运行内存稳定，无明显泄漏 |
| MEM-02 | 日志缓冲区大小可控（maxLogEntries = 100 已实现） |
| MEM-03 | Combine 订阅正确管理，无遗留订阅 |
| MEM-04 | Timer 正确清理，无循环引用 |
| MEM-05 | FileHandle 正确关闭，无资源泄漏 |

### Success Criteria

1. **Stable Memory Footprint:** Memory usage remains bounded after 24+ hours of continuous operation (no linear growth trend)
2. **Clean Shutdown:** All child processes terminate when app quits; no orphan `easytier-core` processes remain
3. **Robust Process Management:** Abnormal process termination (crash, kill) is detected and handled gracefully with user notification
4. **No Resource Leaks:** Memory Graph Debugger shows no leaked FileHandles, Timers, or subscriptions after extended use
5. **Log Stability:** Large log volumes (1000+ entries) don't impact UI responsiveness or memory

### Plans

#### Plan 2.1: Combine Subscription Management

**Goal:** Zero orphan subscriptions

**Tasks:**
1. Audit all `AnyCancellable` storage locations
2. Ensure subscriptions stored in `Set<AnyCancellable>` on owning object
3. Move subscription creation to `init()` only, not in repeated methods
4. Add explicit `cancel()` in `deinit` for critical subscriptions
5. Profile with Memory Graph Debugger for accumulation

**Pattern:**
```swift
private var cancellables = Set<AnyCancellable>()

init() {
    publisher
        .sink { ... }
        .store(in: &cancellables)
}
```

#### Plan 2.2: Timer Lifecycle Management

**Goal:** All timers properly invalidated, no retain cycles

**Tasks:**
1. Audit all Timer usage in codebase
2. Use `[weak self]` in all timer closures
3. Implement `invalidate()` calls in `deinit` or cleanup methods
4. Handle `deinit` from non-MainActor context (dispatch to main if needed)
5. Consider `RunLoop.main` vs `Timer.publish` patterns

**Pattern:**
```swift
private var peerPollTimer: Timer?

func startPolling() {
    peerPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            await self?.pollPeers()
        }
    }
}

func stopPolling() {
    peerPollTimer?.invalidate()
    peerPollTimer = nil
}
```

#### Plan 2.3: Process Management Robustness

**Goal:** Graceful handling of all process lifecycle events

**Tasks:**
1. Add process termination handler to detect crashes
2. Implement cleanup sequence for abnormal termination
3. Add exit code logging for debugging
4. Implement graceful shutdown timeout with force-kill fallback
5. Verify no zombie processes after termination

**Scenarios to Handle:**
- Normal exit (exit code 0)
- Error exit (non-zero exit code)
- Signal termination (SIGTERM, SIGKILL)
- App force-quit

#### Plan 2.4: FileHandle & Resource Cleanup

**Goal:** No leaked file handles or pipes

**Tasks:**
1. Audit `Process.stdout` and `Process.stderr` handle usage
2. Implement explicit `close()` in cleanup methods
3. Use `defer` blocks for cleanup in complex methods
4. Add resource tracking for debugging
5. Profile with `lsof` for open handles

#### Plan 2.5: Memory Stability Testing

**Goal:** Validate memory stability over extended use

**Tasks:**
1. Create memory testing scenario (connect/disconnect cycles)
2. Run Instruments Allocations instrument for baseline
3. Monitor for leaked objects with Memory Graph Debugger
4. Document expected memory footprint range
5. Add memory warning handler (Phase 3 preparation)

---

## Phase 3: UI 优化

**Focus:** UI Polish
**Duration:** ~1 week
**Risk:** LOW

### Objective

Polish the user interface for clarity, consistency, and native macOS design compliance. Information should be well-organized, status clearly visible, and the interface should feel native and refined.

### Requirements Coverage

| ID | Description |
|----|-------------|
| UI-01 | 界面简洁美观，遵循苹果原生设计规范 |
| UI-02 | 信息层次分明，重点突出 |
| UI-03 | 连接状态视觉清晰（图标 + 颜色 + 文字） |
| UI-04 | 节点列表信息完整易读 |
| UI-05 | 日志视图颜色区分，易读性好 |

### Success Criteria

1. **Native Feel:** UI follows macOS Human Interface Guidelines—appropriate spacing, fonts, and control styles
2. **Clear Status Visibility:** Connection status is immediately apparent from icon, color, and text without reading details
3. **Readable Peer List:** Node information is complete, well-formatted, and easy to scan at a glance
4. **Log Clarity:** Log levels are color-coded, timestamps are visible, and entries are easy to read
5. **Information Hierarchy:** Primary information (status, peers) is prominent; secondary information (logs, settings) is accessible but not overwhelming

### Plans

#### Plan 3.1: Connection Status Polish

**Goal:** Connection status instantly clear from visual cues

**Tasks:**
1. Design status icon set (connected, disconnected, connecting, error)
2. Implement color coding for status (green/yellow/red)
3. Add animated indicator for connecting state
4. Ensure status visible in both window and menu bar
5. Add connection duration display when connected

**Status States:**
- Disconnected: Gray icon, "未连接"
- Connecting: Yellow animated icon, "连接中..."
- Connected: Green icon, "已连接" + duration
- Error: Red icon, "错误" + error summary

#### Plan 3.2: Peer List Enhancement

**Goal:** Complete, readable peer information display

**Tasks:**
1. Review peer info fields for completeness
2. Format IP addresses and latency for readability
3. Add sorting options (by latency, by name)
4. Implement proper table/column layout
5. Add peer detail view or tooltip

**Fields to Display:**
- Peer ID/Name
- Virtual IP
- Latency (with color coding)
- Connection type
- Flags (NAT traversal, relay, etc.)

#### Plan 3.3: Log View Refinement

**Goal:** Color-coded, readable log entries

**Tasks:**
1. Implement log level color coding
   - ERROR: Red
   - WARN: Orange
   - INFO: Default
   - DEBUG: Gray
2. Add timestamp formatting
3. Implement log level filter
4. Add search/filter functionality
5. Ensure monospace font for technical logs

#### Plan 3.4: Overall UI Polish

**Goal:** Consistent, native-feeling interface

**Tasks:**
1. Review all views for HIG compliance
2. Standardize spacing and padding
3. Ensure consistent button styles and sizes
4. Add proper keyboard shortcuts
5. Implement accessibility labels

**macOS HIG Checklist:**
- [ ] Appropriate window sizing and resizing
- [ ] Consistent toolbar/sidebar patterns
- [ ] Proper focus handling
- [ ] Standard keyboard navigation
- [ ] VoiceOver compatibility

#### Plan 3.5: Animation & Transitions

**Goal:** Smooth, purposeful animations

**Tasks:**
1. Add `withAnimation` for state transitions
2. Implement smooth status changes
3. Add list insertion/removal animations
4. Ensure animations don't impact performance
5. Keep animations subtle and functional, not decorative

---

## Progress Summary

| Phase | Status | Requirements | Plans | Progress |
|-------|--------|--------------|-------|----------|
| Phase 1: 响应性与交互反馈 | 🔴 Not Started | 11 | 5 | 0% |
| Phase 2: 内存与稳定性 | 🔴 Not Started | 8 | 5 | 0% |
| Phase 3: UI 优化 | 🔴 Not Started | 5 | 5 | 0% |

**Total:** 24 requirements, 15 plans

---

## Risk Assessment

| Risk | Phase | Mitigation |
|------|-------|------------|
| Authorization Services timing varies | Phase 1 | Profile extensively; may need async wrapper with progress |
| Timer cleanup from non-MainActor | Phase 2 | Dispatch to main queue in deinit |
| Log performance with rapid output | Phase 1, 2 | Batch updates with throttle; circular buffer verified |
| Memory leak detection difficulty | Phase 2 | Use Memory Graph Debugger; establish baseline first |

---

## Dependencies

- Phase 2 depends on Phase 1 for stable async patterns
- Phase 3 depends on Phase 2 for stable memory during polish work
- All phases require Instruments for profiling

---

*Roadmap created: 2025-04-24*
*Ready for Phase 1 planning*
