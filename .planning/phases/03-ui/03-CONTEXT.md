# Phase 3: UI 优化 - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

打磨用户界面，使其简洁美观、信息层次分明、遵循 macOS 原生设计规范。连接状态视觉清晰，节点列表信息完整易读，日志视图颜色区分。

**In scope:**
- 连接状态视觉优化（图标、颜色、一致性）
- 节点列表信息展示优化
- 日志视图颜色区分
- 全局间距规范统一
- 键盘快捷键支持

**Out of scope:**
- 启动优化（Phase 1 已完成）
- 内存稳定性（Phase 2 已完成）
- 新功能添加
- 无障碍支持（后续迭代）

</domain>

<decisions>
## Implementation Decisions

### 连接状态视觉
- **D-01:** 系统图标 (SF Symbols) — 使用 SF Symbols 标准图标，简洁一致
- **D-02:** 系统语义色 — 绿/橙/红，符合系统惯例，用户直觉理解
- **D-03:** 不显示连接时长 — 保持简洁，状态已足够表达

### 节点列表信息
- **D-04:** 当前字段足够 — 主机名、IPv4、延迟、连接方式已满足需求
- **D-05:** 保持当前延迟颜色编码 — <50ms 绿色，<150ms 橙色，否则红色
- **D-06:** 不需要节点详情查看 — 列表字段已满足需求，保持简洁

### 整体打磨
- **D-07:** 统一全局间距规范 — 全局统一间距标准，视觉更协调
- **D-08:** 添加键盘快捷键 — ⌘1-4 切换标签页、⌘Q 退出、⌘R 刷新节点
- **D-09:** 暂不考虑无障碍支持 — 工具类应用优先级较低，可后续迭代

### Claude's Discretion
- 具体的间距数值（参考 macOS HIG）
- 快捷键的具体实现方式
- 日志级别颜色的具体色值

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research Findings
- `.planning/research/SUMMARY.md` — 研究摘要，关键发现
- `.planning/research/ARCHITECTURE.md` — 架构模式

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析
- `.planning/codebase/CONVENTIONS.md` — 编码约定

### Prior Phases
- `.planning/phases/01-响应性与交互反馈/01-CONTEXT.md` — Phase 1 决策，Toast 机制
- `.planning/phases/02-内存与稳定性/02-CONTEXT.md` — Phase 2 决策

</canonical_refs>

<code_context>
## Existing Code Insights

### 连接状态 (ConnectionView.swift)
- `statusBadge()` 已实现状态徽章：connected/connecting/error/disconnected
- 颜色已使用系统语义色：.green/.orange/.red
- 菜单栏状态由 MenuBarManager 管理

### 节点列表 (PeersView.swift)
- 完整表格：主机名、IPv4、延迟、连接方式
- `latencyColor()` 已实现延迟颜色编码
- 支持排序和搜索
- Local 节点高亮显示

### 日志视图 (LogView.swift)
- `LogEntryRow` 已有 `logBackgroundColor` 颜色区分
- ERROR 红色背景，WARN 橙色背景
- 等宽字体用于技术信息
- 支持搜索、导出、自动滚动

### 整体设计
- 毛玻璃效果 `.ultraThinMaterial`
- 卡片圆角 20pt
- 阴影 `Color.black.opacity(0.08), radius: 12, y: 4`
- 边框 `Color.white.opacity(0.12), lineWidth: 1`

### Reusable Assets
- Toast 通知机制（Phase 1）
- 状态徽章组件
- 延迟颜色编码函数
- 毛玻璃卡片样式

### Integration Points
- `ContentView.swift` — 标签页切换，快捷键入口
- `ConnectionView.swift` — 状态徽章
- `PeersView.swift` — 节点列表
- `LogView.swift` — 日志视图
- `MenuBarManager.swift` — 菜单栏状态

</code_context>

<specifics>
## Specific Ideas

- 快捷键：⌘1 连接页、⌘2 节点页、⌘3 日志页、⌘4 设置页
- 快捷键：⌘R 刷新当前网络节点列表
- 间距规范：参考 macOS HIG，统一 padding/spacing 值
- 日志颜色：ERROR #FF3B30, WARN #FF9500, INFO 默认

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-ui*
*Context gathered: 2026-04-24*
