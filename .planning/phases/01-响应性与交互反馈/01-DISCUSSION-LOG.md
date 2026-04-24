# Phase 1: 响应性与交互反馈 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2025-04-24
**Phase:** 01-响应性与交互反馈
**Areas discussed:** 启动优化, 加载状态, 错误反馈, 权限处理

---

## 启动优化

| Option | Description | Selected |
|--------|-------------|----------|
| 异步初始化 | 显示加载状态，后台完成初始化 | ✓ |
| 同步启动 | 保持同步，确保启动干净 | |
| 先测量 | 先分析具体瓶颈，再决定 | |

**User's choice:** 异步初始化 (推荐)
**Notes:** 孤儿进程清理和授权检查移到后台

---

## 授权时机

| Option | Description | Selected |
|--------|-------------|----------|
| 延迟授权 | 启动时静默检查，点击连接时才弹窗 | ✓ |
| 启动时授权 | 启动时立即请求，确保连接时已授权 | |

**User's choice:** 延迟授权 (推荐)
**Notes:** 减少启动时的用户干扰

---

## 加载状态显示

| Option | Description | Selected |
|--------|-------------|----------|
| 按钮内进度 | 按钮内 ProgressView + 文字变化 | ✓ |
| 按钮禁用 + 加载器 | 按钮变灰 + 旁边显示加载器 | |
| 区域覆盖 | 整个区域显示加载覆盖层 | |

**User's choice:** 按钮内进度 (推荐)
**Notes:** 连接按钮显示 ProgressView + "连接中..."

---

## 错误反馈方式

| Option | Description | Selected |
|--------|-------------|----------|
| Toast 通知 | 右上角短暂显示，自动消失 | ✓ |
| Alert 对话框 | 模态对话框，需点击关闭 | |
| 内联错误 | 按钮下方红色文字提示 | |

**User's choice:** Toast 通知 (推荐)
**Notes:** 失败时右上角显示，3秒后自动消失

---

## 成功提示

| Option | Description | Selected |
|--------|-------------|----------|
| 成功 + 失败都提示 | 成功也显示 Toast | |
| 仅失败提示 | 状态变化已足够明显 | ✓ |

**User's choice:** 仅失败提示 (推荐)
**Notes:** 连接成功后状态变化已足够明显

---

## 权限失败处理

| Option | Description | Selected |
|--------|-------------|----------|
| 提示 + 重试 | Toast 提示 + 重试按钮 | ✓ |
| Alert 对话框 | Alert 对话框解释原因 | |
| 详细错误 + 帮助 | 显示详细错误 + 帮助链接 | |

**User's choice:** 提示 + 重试 (推荐)
**Notes:** 用户拒绝授权时显示 Toast + 重试按钮

---

## Claude's Discretion

- Toast 组件的具体实现方式（原生 SwiftUI vs 自定义）
- 加载动画的具体样式
- 错误信息的具体文案

## Deferred Ideas

None — discussion stayed within phase scope
