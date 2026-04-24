# Phase 1: 响应性与交互反馈 - Context

**Gathered:** 2025-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

消除主线程阻塞，实现交互反馈。用户操作任何功能都应得到即时视觉反馈，应用启动快速无卡顿，连接/断开操作流畅。

**In scope:**
- 启动优化（孤儿进程清理、授权时机）
- 连接/断开按钮加载状态
- 操作失败 Toast 提示
- 权限失败处理

**Out of scope:**
- 内存泄漏修复（Phase 2）
- 进程管理健壮性（Phase 2）
- UI 美化（Phase 3）

</domain>

<decisions>
## Implementation Decisions

### 启动优化
- **D-01:** 异步初始化 — 启动时显示加载状态，后台完成孤儿进程清理和初始化
- **D-02:** 延迟授权 — 启动时静默检查授权状态，用户点击连接时才弹出授权对话框

### 加载状态
- **D-03:** 按钮内进度 — 连接/断开按钮显示 ProgressView + 文字变化（"连接中..."）
- **D-04:** 操作期间按钮禁用 — 防止用户重复点击

### 错误反馈
- **D-05:** Toast 通知 — 操作失败时右上角短暂显示，自动消失
- **D-06:** 仅失败提示 — 成功时不显示提示，状态变化已足够明显

### 权限处理
- **D-07:** 提示 + 重试 — 用户拒绝授权时显示 Toast 提示 + 重试按钮

### Claude's Discretion
- Toast 组件的具体实现方式（原生 SwiftUI vs 自定义）
- 加载动画的具体样式
- 错误信息的具体文案

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research Findings
- `.planning/research/SUMMARY.md` — 研究摘要，关键发现
- `.planning/research/PITFALLS.md` — 常见陷阱，主线程阻塞模式
- `.planning/research/ARCHITECTURE.md` — 架构模式，MainActor 使用

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析
- `.planning/codebase/CONVENTIONS.md` — 编码约定

</canonical_refs>

<code_context>
## Existing Code Insights

### 启动流程 (EasyTierGUIApp.swift:128-142)
- `cleanupOrphanedProcesses()` — 同步调用，需改为异步
- `checkRootPrivileges()` — 延迟 0.5s 后请求授权
- 菜单栏设置在主线程

### 连接按钮 (ConnectionView.swift:341-360)
- 点击后 `Task { await connect(config) }` — 无加载状态
- 按钮样式已有，但无进度显示
- 有 `validationMessage` + `showValidationAlert` 验证机制

### 错误处理
- `EasyTierError` 枚举已定义用户友好错误信息
- 需添加 Toast 组件

### Reusable Assets
- `NetworkRuntime` 已有 `status: NetworkStatus` 状态枚举
- `ProcessViewModel` 已有 `errorMessage` 属性

### Integration Points
- `ConnectionView.swift` — 连接/断开按钮
- `EasyTierGUIApp.swift` — 启动流程
- `EasyTierService.swift` — 进程管理

</code_context>

<specifics>
## Specific Ideas

- 按钮文字变化：连接 → "连接中..." → 断开
- 按钮颜色变化：蓝色 → 灰色禁用 → 红色
- Toast 位置：右上角，3秒后自动消失

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-响应性与交互反馈*
*Context gathered: 2025-04-24*
