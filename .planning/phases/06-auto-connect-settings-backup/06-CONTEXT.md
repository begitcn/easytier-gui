# Phase 6: Auto-Connect & Settings Backup - Context

**Gathered:** 2026-04-25
**Status:** Ready for planning

<domain>
## Phase Boundary

实现开机自动连接和完整配置备份功能，包括登录项集成、上次使用配置记忆、网络就绪检测，以及全量备份恢复。

**In scope:**
- 上次使用配置记忆（单个配置）
- 网络就绪检测 + 超时机制
- 自动连接失败通知
- 全量备份（配置 + 应用偏好）
- 备份恢复（直接覆盖）
- 登录项集成（保持现有实现）

**Out of scope:**
- 高级设置 UI（Phase 7）
- 快捷连接功能（Phase 7）
- 带宽统计（v2）
- 云同步功能
- 每个配置单独的自动连接开关

</domain>

<decisions>
## Implementation Decisions

### 自动连接行为
- **D-01:** 上次使用的单个配置 — 记住上次连接成功的网络配置，启动时只连接该配置
- **D-02:** 网络就绪检测 + 超时 — 检测网络可用后再连接，最多等待 30 秒，避免无网络时长时间等待
- **D-03:** Toast 通知 + 重试 — 自动连接失败时使用现有 Toast 机制，显示失败原因和重试按钮

### 备份恢复功能
- **D-04:** 配置 + 应用偏好 — 备份文件包含所有网络配置 + AppStorage 偏好设置（开机启动、显示图标等）
- **D-05:** 直接覆盖 — 恢复时直接覆盖所有配置和偏好，与 Phase 4 导入行为一致

### 登录项集成
- **D-06:** 保持现状 — 当前 SMAppService 实现已足够，无需修改

### Claude's Discretion
- 网络就绪检测的具体实现（NWPathMonitor 或其他方式）
- 备份文件命名格式
- 备份文件存储位置默认值

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Codebase
- `.planning/codebase/ARCHITECTURE.md` — 现有架构分析，MVVM 模式
- `.planning/codebase/CONVENTIONS.md` — 编码约定，SwiftUI 模式

### Prior Phases
- `.planning/milestones/v1.0-phases/01-响应性与交互反馈/01-CONTEXT.md` — Phase 1 决策，Toast 机制
- `.planning/phases/04-config-import-export-foundation/04-CONTEXT.md` — Phase 4 决策，导入导出模式

### Key Source Files
- `EasyTierGUI/Views/SettingsView.swift` — OpenAtLoginManager, autoConnectOnLaunch 开关
- `EasyTierGUI/EasyTierGUIApp.swift` — 应用启动生命周期，自动连接逻辑
- `EasyTierGUI/Services/ProcessViewModel.swift` — connectAll(), connect() 方法
- `EasyTierGUI/Services/ConfigManager.swift` — 配置持久化

</canonical_refs>

<code_context>
## Existing Code Insights

### 已实现的登录项功能 (SettingsView.swift)
```swift
struct OpenAtLoginManager {
    func setStartAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } else {
            SMLoginItemSetEnabled(bundleID as CFString, enabled)
        }
    }
}
```

### 已实现的自动连接开关 (SettingsView.swift)
```swift
@AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
Toggle("启动时自动连接", isOn: $autoConnectOnLaunch)
```

### 现有自动连接逻辑 (EasyTierGUIApp.swift)
```swift
.onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
    let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
    if autoConnect {
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await processVM.connectAll()  // 当前连接所有网络
        }
    }
}
```

### AppStorage 偏好设置 (SettingsView.swift)
- `startAtLogin` — 开机启动
- `showMenuBar` — 显示系统托盘图标
- `autoConnectOnLaunch` — 启动时自动连接
- `showDockIcon` — 显示程序坞图标
- `enableLogMonitoring` — 启用日志监控

### Toast 机制 (Phase 1 已实现)
- `ToastMessage` 结构体
- `ToastType`: `.error`, `.warning`, `.info`
- `ToastAction` — 可选的重试按钮
- `ProcessViewModel.showToast()` 方法

### Reusable Assets
- SMAppService 登录项管理
- Toast 通知机制（含重试按钮）
- AppStorage 偏好存储
- ConfigManager 配置导入导出

### Integration Points
- `EasyTierGUIApp.swift` — 修改自动连接逻辑，添加上次配置记忆和网络就绪检测
- `ConfigManager.swift` — 添加 lastConnectedConfigId 持久化
- `SettingsView.swift` — 添加备份/恢复 UI 入口
- 新建 `BackupService.swift` — 备份恢复逻辑

</code_context>

<specifics>
## Specific Ideas

- 上次连接配置 ID 存储位置：`AppStorage("lastConnectedConfigId")`
- 网络就绪检测：使用 `NWPathMonitor` 监听网络状态变化
- 备份文件格式：JSON，包含 `configs` 和 `preferences` 两个顶级字段
- 备份文件命名：`EasyTierGUI-Backup-{日期}.json`
- 备份 UI 入口：设置页面添加"备份设置"和"恢复设置"按钮

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-auto-connect-settings-backup*
*Context gathered: 2026-04-25*
