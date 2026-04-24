# EasyTier GUI 优化项目

## Current Milestone: v1.1 Feature Enhancement

**Goal:** Add user-requested features to enhance EasyTier GUI usability for both beginners and power users.

**Target features:**
- Config import/export — Share network configurations between machines
- Network stats — Visualize topology, latency, bandwidth
- Advanced settings — Protocol options, peer config, debugging
- Auto-connect on startup — Remember and auto-start last network
- Quick-connect shortcuts — Desktop shortcuts to specific networks
- Settings backup/restore — Backup all configs and app settings

## What This Is

EasyTier GUI 的功能增强版本。这是一个 macOS 原生应用，为 EasyTier P2P VPN 提供图形界面。v1.0 已完成性能优化，v1.1 将添加用户请求的新功能：配置导入导出、网络统计、高级设置、自动连接、快捷方式、备份恢复。

## Core Value

**程序稳定运行，交互响应及时，内存长期稳定。** 用户操作任何功能都应得到明确的视觉反馈，应用可长时间常驻运行而不出现卡顿或内存泄漏。

## Requirements

### Validated

<!-- v1.0 已验证的功能 -->

- ✓ 多网络配置并发运行 — 每个配置独立的 NetworkRuntime
- ✓ 内置 EasyTier 核心自动更新 — BinaryManager + GitHubReleaseService
- ✓ 菜单栏集成显示连接状态 — MenuBarManager
- ✓ 实时日志查看器 — LogView + LogEntry 循环缓冲
- ✓ 节点列表显示 — PeersView + PeerInfo
- ✓ 配置持久化 — ConfigManager JSON 存储
- ✓ 权限提升执行 — PrivilegedExecutor (Objective-C 桥接)
- ✓ 通用二进制支持 — arm64 + x86_64

<!-- v1.0 新验证的需求 -->

- ✓ **PERF-01**: 启动时无卡顿，快速响应 — v1.0 Phase 1
- ✓ **PERF-02**: 连接/断开操作流畅，无 spinning ball — v1.0 Phase 1
- ✓ **PERF-03**: 所有耗时操作在后台队列执行 — v1.0 Phase 1
- ✓ **PERF-04**: 日志滚动流畅，无卡顿 — v1.0 Phase 1
- ✓ **STAB-01**: 进程管理健壮，异常情况优雅处理 — v1.0 Phase 2
- ✓ **STAB-02**: 应用退出时无孤儿进程残留 — v1.0 Phase 2
- ✓ **STAB-03**: 权限错误有明确提示和处理 — v1.0 Phase 1
- ✓ **STAB-04**: 大量日志不影响应用稳定性 — v1.0 Phase 2
- ✓ **MEM-01**: 长时间运行内存稳定，无明显泄漏 — v1.0 Phase 2
- ✓ **MEM-02**: 日志缓冲区大小可控 (maxLogEntries = 100) — v1.0 Phase 2
- ✓ **MEM-03**: Combine 订阅正确管理，无遗留订阅 — v1.0 Phase 2
- ✓ **MEM-04**: Timer 正确清理，无循环引用 — v1.0 Phase 2
- ✓ **MEM-05**: FileHandle 正确关闭，无资源泄漏 — v1.0 Phase 2
- ✓ **INT-01**: 连接按钮点击后立即显示加载状态 — v1.0 Phase 1
- ✓ **INT-02**: 断开按钮点击后立即显示加载状态 — v1.0 Phase 1
- ✓ **INT-03**: 操作成功有明确提示 — v1.0 Phase 1 (状态变化已足够)
- ✓ **INT-04**: 操作失败有明确提示 — v1.0 Phase 1
- ✓ **INT-05**: 加载状态清晰可见 — v1.0 Phase 1
- ✓ **INT-06**: 错误信息用户友好 — v1.0 Phase 1
- ✓ **UI-01**: 界面简洁美观，遵循苹果原生设计规范 — v1.0 Phase 3
- ✓ **UI-02**: 信息层次分明，重点突出 — v1.0 Phase 3
- ✓ **UI-03**: 连接状态视觉清晰 — v1.0 Phase 3
- ✓ **UI-04**: 节点列表信息完整易读 — v1.0 Phase 3
- ✓ **UI-05**: 日志视图颜色区分，易读性好 — v1.0 Phase 3

### Active

<!-- v1.1 目标 -->

- [ ] **FEAT-01**: 用户可以导入/导出网络配置文件
- [ ] **FEAT-02**: 用户可以查看网络拓扑、延迟、带宽统计
- [ ] **FEAT-03**: 用户可以配置高级选项（协议、peer 配置、调试选项）
- [ ] **FEAT-04**: 用户可以设置应用启动时自动连接上次网络
- [ ] **FEAT-05**: 用户可以创建桌面快捷方式快速连接特定网络
- [ ] **FEAT-06**: 用户可以备份/恢复应用设置和所有网络配置

### Out of Scope

<!-- 明确不在本次范围内 -->

- 新协议支持 — 需要 EasyTier core 更新
- 跨平台支持 — 仅关注 macOS
- 国际化/本地化 — 不在本次范围
- 单元测试覆盖 — 可作为后续工作
- 重写整个应用 — 保持现有架构，增量添加功能

## Context

### 当前状态

**Shipped v1.0** — 2026-04-24

- 3 phases, 15 plans, 50 commits
- 5,703 Swift LOC
- All 24 v1 requirements verified

**技术栈:** Swift 5.9 + SwiftUI + Combine + AppKit

### 已解决问题

- ✅ 启动卡顿 → 异步初始化 + 加载指示器
- ✅ 连接/断开卡顿 → 后台队列执行 + 即时视觉反馈
- ✅ 内存增长 → Combine/Timer/FileHandle 正确清理
- ✅ 交互反馈缺失 → 按钮加载状态 + Toast 通知
- ✅ UI 不够原生 → macOS HIG 8pt grid + SF Symbols

### 技术债务

(无已知技术债务)

## Constraints

- **技术栈**: Swift 5.9 + SwiftUI + Combine + AppKit，不引入新框架
- **兼容性**: macOS 14.0+，保持通用二进制支持
- **架构**: 保持 MVVM 模式，不大幅重构
- **权限**: 仍需 root 权限创建 TUN 设备

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 保持现有 MVVM 架构 | 架构合理，问题在实现细节 | ✓ Good |
| 原生简洁 UI 风格 | 符合用户期望，减少过度设计 | ✓ Good |
| 全面优化而非局部修复 | 多处关联，系统性解决更有效 | ✓ Good |
| 异步初始化 + 加载指示器 | D-01: 用户感知而非实际速度 | ✓ Good |
| 按钮加载状态 + 禁用 | D-03/D-04: 即时反馈防止重复操作 | ✓ Good |
| Toast 通知替代 Alert | D-05: 非阻塞错误提示 | ✓ Good |
| 延迟权限请求 | D-02: 仅在连接时提示，减少启动干扰 | ✓ Good |
| 日志节流 100ms | 防止 UI 过度渲染 | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

---
*Last updated: 2026-04-24 after starting v1.1 milestone*
