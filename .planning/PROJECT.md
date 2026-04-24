# EasyTier GUI 优化项目

## What This Is

EasyTier GUI 的性能与体验优化项目。这是一个现有的 macOS 原生应用，为 EasyTier P2P VPN 提供图形界面。本次优化聚焦于**性能、稳定性、交互反馈、内存管理、UI 简洁度**，不添加新功能。

## Core Value

**程序稳定运行，交互响应及时，内存长期稳定。** 用户操作任何功能都应得到明确的视觉反馈，应用可长时间常驻运行而不出现卡顿或内存泄漏。

## Requirements

### Validated

<!-- 现有已实现的功能，经过验证 -->

- ✓ 多网络配置并发运行 — 每个配置独立的 NetworkRuntime
- ✓ 内置 EasyTier 核心自动更新 — BinaryManager + GitHubReleaseService
- ✓ 菜单栏集成显示连接状态 — MenuBarManager
- ✓ 实时日志查看器 — LogView + LogEntry 循环缓冲
- ✓ 节点列表显示 — PeersView + PeerInfo
- ✓ 配置持久化 — ConfigManager JSON 存储
- ✓ 权限提升执行 — PrivilegedExecutor (Objective-C 桥接)
- ✓ 通用二进制支持 — arm64 + x86_64

### Active

<!-- 本次优化目标 -->

- [ ] **PERF-01**: 启动时无卡顿，快速响应
- [ ] **PERF-02**: 连接/断开操作流畅，无 spinning ball
- [ ] **STAB-01**: 所有操作在主线程保持响应，耗时操作异步执行
- [ ] **STAB-02**: 进程管理健壮，异常情况优雅处理
- [ ] **MEM-01**: 长时间运行内存稳定，无明显泄漏
- [ ] **MEM-02**: 日志缓冲区大小可控，不无限增长
- [ ] **MEM-03**: Combine 订阅正确管理，无遗留订阅
- [ ] **INT-01**: 所有按钮点击有即时视觉反馈
- [ ] **INT-02**: 操作成功/失败有明确提示（Toast/Alert）
- [ ] **INT-03**: 加载状态清晰可见（进度指示器）
- [ ] **INT-04**: 错误信息用户友好，可理解
- [ ] **UI-01**: 界面简洁美观，遵循苹果原生设计规范
- [ ] **UI-02**: 信息层次分明，重点突出
- [ ] **UI-03**: 避免过度设计，保持克制

### Out of Scope

<!-- 明确不在本次范围内 -->

- 添加新功能（如新协议支持、新 UI 页面）— 本次只优化现有功能
- 重写整个应用 — 保持现有架构，针对性优化
- 跨平台支持 — 仅关注 macOS
- 国际化/本地化 — 不在本次范围
- 单元测试覆盖 — 可作为后续工作

## Context

### 现有架构

**MVVM 模式：**
- View Layer: SwiftUI 视图 (ContentView, ConnectionView, PeersView, LogView, SettingsView)
- ViewModel Layer: ProcessViewModel (主协调器), NetworkRuntime (单网络状态)
- Service Layer: EasyTierService, ConfigManager, BinaryManager, MenuBarManager
- System Layer: PrivilegedExecutor (Objective-C 权限桥接)

**关键技术点：**
- Combine 框架用于响应式状态管理
- `@MainActor` 保证 UI 线程安全
- Process 管理 easytier-core 子进程
- Timer 定时轮询节点信息

### 已知问题点

**启动卡顿：**
- 可能原因：启动时同步操作阻塞主线程
- 需排查：AppDelegate.applicationDidFinishLaunching 中的操作

**连接/断开卡顿：**
- 可能原因：权限检查、进程启动在主线程执行
- 需排查：EasyTierService.start() 和 ProcessViewModel.connect()

**内存轻微增长：**
- 可能原因：Combine 订阅未释放、日志缓冲累积、Timer 未正确清理
- 需排查：AnyCancellable 存储、Timer invalidate、循环引用

**交互反馈缺失：**
- 点击连接按钮后无加载状态
- 成功/失败无提示
- 错误信息技术性太强

## Constraints

- **技术栈**: Swift 5.9 + SwiftUI + Combine + AppKit，不引入新框架
- **兼容性**: macOS 14.0+，保持通用二进制支持
- **架构**: 保持 MVVM 模式，不大幅重构
- **权限**: 仍需 root 权限创建 TUN 设备

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持现有 MVVM 架构 | 架构合理，问题在实现细节 | — Pending |
| 原生简洁 UI 风格 | 符合用户期望，减少过度设计 | — Pending |
| 全面优化而非局部修复 | 多处关联，系统性解决更有效 | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2025-04-24 after initialization*
