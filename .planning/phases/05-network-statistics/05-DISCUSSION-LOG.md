# Phase 5: Network Statistics - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 05-network-statistics
**Areas discussed:** 带宽统计, 拓扑可视化, 数据更新策略, Stats UI 位置, 层级结构, 视觉样式

---

## 带宽统计数据来源

| Option | Description | Selected |
|--------|-------------|----------|
| 扩展 CLI 输出解析 | 需要确认 easytier-cli 是否返回 bytes_sent/bytes_received 字段 | |
| RPC Portal API | 调用 easytier-core 的 RPC API 获取详细统计数据 | |
| 仅延迟统计 | 在节点列表显示延迟（已实现），带宽统计延后到 v2 | ✓ |

**User's choice:** 仅延迟统计
**Notes:** 当前阶段专注于延迟显示，带宽统计延后到 v2 版本

---

## 网络拓扑可视化程度

| Option | Description | Selected |
|--------|-------------|----------|
| 交互式图形拓扑 | 用 SwiftUI Canvas 绘制，支持节点拖拽和缩放，类似网络拓扑图工具 | |
| 简化层级视图 | 用树状或层级结构显示节点关系，类似 PeersView 但有连线标识 | ✓ |
| 延后拓扑功能 | 仅用表格显示节点列表，拓扑可视化延后到 v2（与带宽统计一起） | |

**User's choice:** 简化层级视图
**Notes:** 选择轻量级实现，本机为中心的树状结构

---

## 统计数据刷新间隔

| Option | Description | Selected |
|--------|-------------|----------|
| 保持 5 秒 | 当前已有的 5 秒轮询间隔足够，无需调整 | ✓ |
| 2 秒间隔 | 增加轮询频率，更及时的数据更新 | |
| 可配置间隔 | 让用户在设置中选择刷新频率 | |

**User's choice:** 保持 5 秒
**Notes:** 复用现有机制，避免增加 CPU 负载

---

## 断开连接时过期数据显示

| Option | Description | Selected |
|--------|-------------|----------|
| 灰显 + 标签 | 显示灰色文字 + "已断开" 标签，保留最后数据供参考 | ✓ |
| 清空显示 | 清空所有数据，显示 "未连接" 状态 | |
| 删除线样式 | 保留数据但添加删除线，标识为历史数据 | |

**User's choice:** 灰显 + 标签
**Notes:** 保留历史数据供用户参考

---

## 统计 UI 位置

| Option | Description | Selected |
|--------|-------------|----------|
| 扩展现有 PeersView | 在现有 PeersView 中添加拓扑视图区域，保持单一节点标签页 | ✓ |
| 新建 StatsView 标签页 | 新增 "统计" 标签页，专门展示网络统计和拓扑 | |
| 节点详情弹窗 | 在节点详情弹窗中显示扩展统计数据 | |

**User's choice:** 扩展现有 PeersView
**Notes:** 保持 UI 简洁，不增加新标签页

---

## 简化层级视图结构

| Option | Description | Selected |
|--------|-------------|----------|
| 本机中心视图 | 显示本机节点为根，所有 peer 为直接子节点（P2P 网络常用） | ✓ |
| 路由关系视图 | 如果有路由信息，显示多跳节点关系 | |
| 连接方式分组 | 按直连/中继分组显示节点 | |

**User's choice:** 本机中心视图
**Notes:** 符合 P2P 网络特点，实现简单

---

## 拓扑视图视觉呈现

| Option | Description | Selected |
|--------|-------------|----------|
| 连接线 + 延迟标注 | 用线条连接节点，显示延迟数值在线上 | ✓ |
| 列表形式 | 仅用列表形式，延迟通过颜色编码（已有，基本等同于现状） | |
| 动画拓扑图 | 带动画效果的节点和连线，更直观但有性能开销 | |

**User's choice:** 连接线 + 延迟标注
**Notes:** 使用 SwiftUI Canvas 绘制，轻量级可视化

---

## Claude's Discretion

- 拓扑图的具体布局算法（圆形、网格、力导向）
- 拓扑视图的默认展开/折叠状态
- 节点和连接线的颜色/样式细节
- "已断开" 标签的具体文案

## Deferred Ideas

None — discussion stayed within phase scope
