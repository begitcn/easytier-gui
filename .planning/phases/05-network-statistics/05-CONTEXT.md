# Phase 5: Network Statistics - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

实现网络统计功能，让用户查看延迟数据、网络拓扑可视化，以及断开连接时的视觉反馈。

**In scope:**
- 延迟统计显示（已有 latencyMs，需扩展展示）
- 网络拓扑可视化（简化层级视图）
- 断开连接时的过期数据标识
- 统计数据定期刷新机制

**Out of scope:**
- 带宽统计（bytes_sent/bytes_received）— 延后到 v2
- 实时数据更新（避免 CPU 负载）
- 交互式拓扑图编辑
- 网络性能分析报告

</domain>

<decisions>
## Implementation Decisions

### 带宽统计
- **D-01:** 仅延迟统计 — 当前阶段仅实现延迟显示，带宽统计（bytes_sent/bytes_received）延后到 v2
- **D-02:** 复用现有 latencyMs — PeerInfo 已有 latencyMs 字段，PeersView 已显示延迟

### 拓扑可视化
- **D-03:** 简化层级视图 — 本机为中心，所有 peer 为直接子节点的树状结构
- **D-04:** 连接线 + 延迟标注 — 用线条连接节点，延迟数值显示在连接线上
- **D-05:** SwiftUI Canvas 绘制 — 使用 Canvas 绘制拓扑图，支持基本交互

### 数据更新策略
- **D-06:** 保持 5 秒轮询 — 复用现有 peerTimer 机制，不增加轮询频率
- **D-07:** 非实时更新 — 避免频繁 UI 更新造成的 CPU 负载

### 过期数据标识
- **D-08:** 灰显 + 标签 — 断开连接时，节点数据变灰并显示 "已断开" 标签
- **D-09:** 保留历史数据 — 不清空数据，让用户能看到最后的状态

### UI 位置
- **D-10:** 扩展现有 PeersView — 在节点列表上方或侧边添加拓扑视图区域
- **D-11:** 可折叠拓扑视图 — 允许用户展开/折叠拓扑图，节省屏幕空间

### Claude's Discretion
- 拓扑图的具体布局算法（圆形、网格、力导向）
- 拓扑视图的默认展开/折叠状态
- 节点和连接线的颜色/样式细节
- "已断开" 标签的具体文案

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析，MVVM 模式
- `.planning/codebase/CONVENTIONS.md` — 编码约定，SwiftUI 模式

### Prior Phases
- `.planning/milestones/v1.0-phases/01-响应性与交互反馈/01-CONTEXT.md` — Phase 1 决策，Toast 机制
- `.planning/milestones/v1.0-phases/03-ui/03-CONTEXT.md` — Phase 3 决策，UI 风格
- `.planning/phases/04-config-import-export-foundation/04-CONTEXT.md` — Phase 4 决策，复用模式

### Key Source Files
- `EasyTierGUI/Models/Models.swift` — PeerInfo 模型，已有 latencyMs
- `EasyTierGUI/Services/EasyTierService.swift` — fetchPeers() 方法，peer polling
- `EasyTierGUI/Services/ProcessViewModel.swift` — NetworkRuntime，peerTimer
- `EasyTierGUI/Views/PeersView.swift` — 现有节点列表视图

</canonical_refs>

<code_context>
## Existing Code Insights

### PeerInfo Model (Models.swift)
```swift
struct PeerInfo: Identifiable, Equatable {
    var id: String { "\(nodeID)|\(ipv4)" }
    var nodeID: String
    var ipv4: String
    var hostname: String
    var status: PeerStatus
    var latencyMs: Double?    // 已有延迟字段
    var cost: String?
    var tunnelProto: String?
    var location: String?
}
```

### Peer Polling (ProcessViewModel.swift)
- `NetworkRuntime.peerTimer` — 5 秒轮询间隔
- `fetchPeers()` 调用 `EasyTierService.fetchPeers()`
- `easytier-cli -p 127.0.0.1:{port} -o json peer list`

### PeersView (Views/PeersView.swift)
- 节点列表显示：主机名、IPv4、延迟、连接方式
- 延迟颜色编码：<50ms 绿色，<150ms 橙色，>=150ms 红色
- 支持 UI 复用和扩展

### Toast 机制 (Phase 1 已实现)
- `ToastMessage` 结构体
- `ToastType`: `.error`, `.warning`, `.info`
- `ProcessViewModel.showToast()` 方法

### Reusable Assets
- PeerInfo 模型已有延迟字段
- Peer polling 机制完整
- Toast 通知机制
- SwiftUI Canvas 绘制能力
- PeersView 现有布局和样式

### Integration Points
- `PeersView.swift` — 添加拓扑视图区域
- `PeerInfo` — 可能需要扩展字段（未来带宽统计）
- `EasyTierService.fetchPeers()` — 数据源

</code_context>

<specifics>
## Specific Ideas

- 拓扑视图布局：本机节点在中央，peer 节点围绕排列
- 连接线样式：渐变线条，颜色根据延迟变化（绿→橙→红）
- 拓扑视图默认折叠，点击展开显示
- "已断开" 标签使用灰色胶囊样式
- 拓扑图使用 SF Symbols 节点图标

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-network-statistics*
*Context gathered: 2026-04-25*
