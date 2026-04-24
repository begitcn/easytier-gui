# Phase 2: 内存与稳定性 - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 02-内存与稳定性
**Areas discussed:** 进程异常处理, 应用退出清理, 内存验证方法, 资源泄漏检测

---

## 进程异常处理

### 进程终止处理策略

| Option | Description | Selected |
|--------|-------------|----------|
| 检测 + Toast 通知 | 进程终止时立即检测，更新 UI 状态，显示 Toast 通知用户 | ✓ |
| 检测 + 自动重启 | 检测后自动尝试重新启动进程，最多重试 3 次 | |
| 静默处理 | 仅记录到日志，不干扰用户，用户可手动重新连接 | |

**User's choice:** 检测 + Toast 通知
**Notes:** 用户倾向简单明确的错误提示，不自动重启

### 退出码区分

| Option | Description | Selected |
|--------|-------------|----------|
| 区分并记录 | 正常退出(0)、错误退出(非0)、信号终止(SIGTERM/SIGKILL)分别记录，便于调试 | ✓ |
| 简单二分 | 仅区分正常/异常，不细分具体原因 | |
| 不区分 | 所有终止统一处理，不区分原因 | |

**User's choice:** 区分并记录
**Notes:** 便于调试和问题追踪

---

## 应用退出清理

### 进程终止策略

| Option | Description | Selected |
|--------|-------------|----------|
| 优雅 + 超时强制 | 优雅终止（SIGTERM）→ 等待 3 秒 → 强制终止（SIGKILL） | ✓ |
| 立即强制终止 | 直接发送 SIGKILL，快速但可能导致数据丢失 | |
| 仅优雅终止 | 仅发送 SIGTERM，不强制终止，可能残留孤儿进程 | |

**User's choice:** 优雅 + 超时强制
**Notes:** 平衡用户体验和清理可靠性

### 清理顺序

| Option | Description | Selected |
|--------|-------------|----------|
| 明确顺序 | 停止进程 → 取消 Timer → 释放订阅 → 关闭 FileHandle，顺序执行 | ✓ |
| 并行清理 | 所有资源同时开始清理，不保证顺序 | |

**User's choice:** 明确顺序
**Notes:** 避免资源依赖导致的清理问题

---

## 内存验证方法

### 验证工具选择

| Option | Description | Selected |
|--------|-------------|----------|
| Memory Graph Debugger | 使用 Xcode Memory Graph Debugger 检查泄漏对象，手动验证 | ✓ |
| Instruments Allocations | 使用 Instruments Allocations 监控内存增长趋势 | ✓ |
| 代码断言检查 | 在代码中添加调试断言检查已知问题点 | ✓ |
| 自动化测试场景 | 创建自动化测试场景（连接/断开循环），监控内存 | ✓ |

**User's choice:** 全选
**Notes:** 多种方法结合使用，确保全面覆盖

---

## 资源泄漏检测

### 检测方法

| Option | Description | Selected |
|--------|-------------|----------|
| deinit 日志 | 在 deinit 中添加日志，确认对象正确释放 | ✓ |
| 资源跟踪器 | 创建 ResourceTracker 类跟踪所有资源分配和释放 | |
| 仅手动检查 | 仅依赖 Memory Graph Debugger 进行手动检查 | |

**User's choice:** deinit 日志
**Notes:** 简单有效，不引入额外复杂度

### Timer 清理方式

| Option | Description | Selected |
|--------|-------------|----------|
| weak self + invalidate | 使用 [weak self] 防止循环引用，在 deinit/stop 方法中 invalidate | ✓ |
| Combine Timer | 使用 Combine Timer.publish 取代 Timer，自动随订阅释放 | |
| Claude 决定 | 两种方式都可以，由 Claude 根据上下文选择 | |

**User's choice:** weak self + invalidate
**Notes:** 保持现有代码风格，最小改动

---

## Claude's Discretion

- 具体的 terminationHandler 实现细节
- 资源清理的超时时间（默认 3 秒）
- 日志输出的具体格式

## Deferred Ideas

None — discussion stayed within phase scope
