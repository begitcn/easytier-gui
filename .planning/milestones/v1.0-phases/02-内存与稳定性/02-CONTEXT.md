# Phase 2: 内存与稳定性 - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

确保长期内存稳定性、健壮的进程管理、正确的资源生命周期处理。应用应能无限期运行而不出现内存增长或资源泄漏，应用退出时无孤儿进程残留。

**In scope:**
- 进程异常终止检测与处理
- 应用退出时资源清理
- Combine 订阅正确管理
- Timer 正确清理
- FileHandle 正确关闭
- 内存稳定性验证

**Out of scope:**
- 启动优化（Phase 1 已完成）
- 交互反馈（Phase 1 已完成）
- UI 美化（Phase 3）

</domain>

<decisions>
## Implementation Decisions

### 进程异常处理
- **D-01:** 检测 + Toast 通知 — 进程意外终止时更新 UI 状态并显示 Toast 通知用户
- **D-02:** 区分并记录退出原因 — 正常退出(0)、错误退出(非0)、信号终止(SIGTERM/SIGKILL)分别记录到日志

### 应用退出清理
- **D-03:** 优雅 + 超时强制 — SIGTERM → 等待 3 秒 → SIGKILL
- **D-04:** 明确顺序清理 — 停止进程 → 取消 Timer → 释放订阅 → 关闭 FileHandle

### 内存验证方法
- **D-05:** Memory Graph Debugger — 手动检查泄漏对象
- **D-06:** Instruments Allocations — 监控内存增长趋势
- **D-07:** 代码断言检查 — 在关键位置添加调试断言
- **D-08:** 自动化测试场景 — 连接/断开循环测试，监控内存

### 资源泄漏检测
- **D-09:** deinit 日志 — 在 deinit 中添加日志确认对象正确释放
- **D-10:** weak self + invalidate — Timer 使用 [weak self] 防止循环引用，在 deinit/stop 中 invalidate

### Claude's Discretion
- 具体的 terminationHandler 实现细节
- 资源清理的超时时间（默认 3 秒）
- 日志输出的具体格式

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research Findings
- `.planning/research/SUMMARY.md` — 研究摘要，关键发现
- `.planning/research/PITFALLS.md` — 常见陷阱，内存泄漏模式
- `.planning/research/ARCHITECTURE.md` — 架构模式，资源生命周期

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析
- `.planning/codebase/CONVENTIONS.md` — 编码约定

### Prior Phase
- `.planning/phases/01-响应性与交互反馈/01-CONTEXT.md` — Phase 1 决策，Toast 机制已建立

</canonical_refs>

<code_context>
## Existing Code Insights

### 进程管理 (EasyTierService.swift)
- `Process` 对象存储在 `private var process: Process?`
- 无 `terminationHandler` 设置 — 需要添加
- `forceStop()` 方法存在但无优雅终止超时机制
- `cleanupOrphanedProcesses()` 静态方法用于启动时清理

### Timer 管理 (ProcessViewModel.swift, EasyTierService.swift)
- `NetworkRuntime` 有 `peerTimer: Timer?` 和 `deinit` 清理
- `EasyTierService` 有 `privilegedLogTimer: Timer?`
- 已使用 `[weak self]` 在 Timer 闭包中

### Combine 订阅
- `NetworkRuntime` 有 `cancellables = Set<AnyCancellable>()`
- `ProcessViewModel` 有 `cancellables = Set<AnyCancellable>()`
- 订阅使用 `.store(in: &cancellables)` 存储

### FileHandle
- `EasyTierService` 有 `outputPipe: Pipe?`
- `startAsyncRead()` 设置 `readabilityHandler`
- `stop()` 清理 `readabilityHandler = nil`

### Reusable Assets
- Toast 通知机制（Phase 1 已实现）— 可用于进程异常通知
- `NetworkRuntime.deinit` 已存在 — 可扩展添加日志

### Integration Points
- `EasyTierService.swift` — 添加 terminationHandler
- `ProcessViewModel.swift` — 扩展 deinit 清理
- `EasyTierGUIApp.swift` — 应用退出清理入口

</code_context>

<specifics>
## Specific Ideas

- 进程终止时 Toast 消息："EasyTier 核心意外退出，请检查日志"
- deinit 日志格式：`[DEBUG] NetworkRuntime deinit - id: {id}`
- 优雅终止超时：3 秒

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-内存与稳定性*
*Context gathered: 2026-04-24*
