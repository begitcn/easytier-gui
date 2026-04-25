# Phase 6: Auto-Connect & Settings Backup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-25
**Phase:** 06-auto-connect-settings-backup
**Areas discussed:** 自动连接行为, 备份恢复功能, 登录项集成

---

## 自动连接行为

### 连接目标选择

| Option | Description | Selected |
|--------|-------------|----------|
| 上次使用的单个配置 | 记住上次连接成功的网络配置，启动时只连接该配置（更智能） | ✓ |
| 所有配置 | 当前行为 - 启动时连接所有已保存的网络配置 | |
| 每个配置单独开关 | 用户可以为每个配置单独设置"自动连接"开关 | |

**User's choice:** 上次使用的单个配置
**Notes:** 更智能的连接策略，避免启动时连接所有网络造成资源冲突

### 网络就绪检测

| Option | Description | Selected |
|--------|-------------|----------|
| 网络就绪检测 + 超时 | 检测网络可用后再连接，最多等待 30 秒，避免无网络时长时间等待 | ✓ |
| 固定延迟 800ms | 当前行为 - 固定等待 800ms 后连接，简单但不保证网络可用 | |
| 无等待 | 立即连接，不等待网络就绪，依赖 EasyTier 自身的重连机制 | |

**User's choice:** 网络就绪检测 + 超时
**Notes:** 使用 NWPathMonitor 监听网络状态，确保在真正有网络时才尝试连接

### 失败通知

| Option | Description | Selected |
|--------|-------------|----------|
| Toast 通知 + 重试 | 使用现有 Toast 机制，显示失败原因和重试按钮 | ✓ |
| 系统通知 | macOS 系统通知，用户可在通知中心查看 | |
| 静默失败 | 不通知，用户可在节点列表看到连接状态 | |

**User's choice:** Toast 通知 + 重试
**Notes:** 复用 Phase 1 的 Toast 机制，保持 UI 一致性

---

## 备份恢复功能

### 备份范围

| Option | Description | Selected |
|--------|-------------|----------|
| 配置 + 应用偏好 | 包含所有网络配置 + AppStorage 偏好设置（开机启动、显示图标等） | ✓ |
| 仅网络配置 | 仅备份网络配置，不含应用偏好设置 | |
| 全部（含内核版本） | 包含配置、偏好、以及 EasyTier 内核版本信息 | |

**User's choice:** 配置 + 应用偏好
**Notes:** 完整的用户体验备份，用户恢复后无需重新配置偏好

### 冲突处理

| Option | Description | Selected |
|--------|-------------|----------|
| 直接覆盖 | 恢复时直接覆盖所有配置和偏好，与 Phase 4 导入行为一致 | ✓ |
| 用户确认对话框 | 显示对话框让用户选择：全部替换 / 逐项确认 / 取消 | |
| 合并（保留现有） | 保留现有配置，仅添加备份中不存在的配置 | |

**User's choice:** 直接覆盖
**Notes:** 简化流程，与 Phase 4 的导入行为保持一致

---

## 登录项集成

| Option | Description | Selected |
|--------|-------------|----------|
| 保持现状 | 当前实现已足够，无需修改（SMAppService + 开关已在 SettingsView） | ✓ |
| 静默启动（隐藏窗口） | 启动时不显示主窗口，仅在菜单栏显示图标 | |
| 关联自动连接开关 | 自动连接启用时强制开启登录项，禁用时自动关闭 | |

**User's choice:** 保持现状
**Notes:** 现有 OpenAtLoginManager + SMAppService 实现已满足需求

---

## Claude's Discretion

- 网络就绪检测的具体实现（NWPathMonitor 或其他方式）
- 备份文件命名格式
- 备份文件存储位置默认值

## Deferred Ideas

None — discussion stayed within phase scope
