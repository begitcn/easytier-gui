# Phase 3: UI 优化 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 03-ui
**Areas discussed:** 连接状态视觉, 节点列表信息, 整体打磨

---

## 连接状态视觉

| Option | Description | Selected |
|--------|-------------|----------|
| 系统图标 (SF Symbols) | 使用 SF Symbols 标准图标，简洁一致 | ✓ |
| 自定义图标 | 自定义设计图标，更独特但增加维护成本 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 系统语义色 | 绿/橙/红，符合系统惯例，用户直觉理解 | ✓ |
| 自定义品牌色 | 使用品牌色调，更独特但可能混淆 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 显示连接时长 | 在状态旁显示已连接时间，用户可感知网络稳定性 | |
| 不显示 | 保持简洁，状态已足够表达 | ✓ |

**User's choice:** 系统图标 + 系统语义色 + 不显示连接时长
**Notes:** 保持简洁原生风格，遵循 macOS 设计惯例

---

## 节点列表信息

| Option | Description | Selected |
|--------|-------------|----------|
| 当前字段足够 | 主机名、IPv4、延迟、连接方式 (当前实现) | ✓ |
| 增加更多字段 | 添加节点 ID、协议类型等更多信息 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 保持当前 (<50ms 绿, <150ms 橙, 否则红) | 当前阈值合理，符合常见网络延迟感知 | ✓ |
| 自定义阈值 | 我来指定具体的颜色和阈值 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 不需要 | 列表字段已满足需求，保持简洁 | ✓ |
| 添加悬浮详情 | 悬停/点击时弹出详情卡片显示完整信息 | |

**User's choice:** 当前字段足够 + 保持当前延迟颜色编码 + 不需要详情查看
**Notes:** 现有实现已满足需求，保持简洁

---

## 整体打磨

| Option | Description | Selected |
|--------|-------------|----------|
| 统一规范 | 全局统一间距标准，视觉更协调 | ✓ |
| 保持现状 | 当前间距已足够好，无需调整 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 添加常用快捷键 | ⌘1-4 切换标签页、⌘Q 退出、⌘R 刷新节点 | ✓ |
| 不需要 | 保持当前菜单栏操作方式 | |

| Option | Description | Selected |
|--------|-------------|----------|
| 添加基础支持 | 添加 VoiceOver 标签、动态字体支持 | |
| 暂不考虑 | 工具类应用优先级较低，可后续迭代 | ✓ |

**User's choice:** 统一间距规范 + 添加键盘快捷键 + 暂不考虑无障碍
**Notes:** 快捷键提升效率，无障碍支持留待后续

---

## Claude's Discretion

- 具体的间距数值（参考 macOS HIG）
- 快捷键的具体实现方式
- 日志级别颜色的具体色值

## Deferred Ideas

None — discussion stayed within phase scope
