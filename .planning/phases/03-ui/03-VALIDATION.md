---
phase: 03
slug: ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Package Manager Tests (XCTest) |
| **Config file** | None — Xcode native |
| **Quick run command** | `xcodebuild test -scheme EasyTierGUI -destination 'platform=macOS' -only-testing:EasyTierGUITests 2>/dev/null` |
| **Full suite command** | `xcodebuild test -scheme EasyTierGUI -destination 'platform=macOS' 2>/dev/null` |
| **Estimated runtime** | ~60 seconds |

**Note:** 此阶段主要是 UI 优化，以手动验证为主。构建验证作为基础自动化检查。

---

## Sampling Rate

- **After every task commit:** Run `./build.sh` (编译验证)
- **After every plan wave:** 手动启动应用进行视觉验证
- **Before `/gsd-verify-work`:** 构建成功 + 手动 UAT 完成
- **Max feedback latency:** 30 seconds (编译时间)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | UI-01 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-01-02 | 01 | 1 | UI-02 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-02-01 | 02 | 1 | UI-01 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-02-02 | 02 | 1 | UI-02 | N/A | N/A | manual | 启动应用测试快捷键 | ✅ | ⬜ pending |
| 03-03-01 | 03 | 2 | UI-05 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-03-02 | 03 | 2 | UI-05 | N/A | N/A | manual | 检查日志颜色显示 | ✅ | ⬜ pending |
| 03-04-01 | 04 | 2 | UI-03 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-04-02 | 04 | 2 | UI-03 | N/A | N/A | manual | 检查连接状态动画 | ✅ | ⬜ pending |
| 03-05-01 | 05 | 3 | UI-01 | N/A | N/A | build | `./build.sh` | ✅ | ⬜ pending |
| 03-05-02 | 05 | 3 | UI-04 | N/A | N/A | manual | 检查节点列表布局 | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

**无需 Wave 0** — 现有基础设施覆盖所有阶段需求。

构建脚本 `./build.sh` 已存在，可直接使用。

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 键盘快捷键切换标签页 | UI-01, UI-02 | UI 交互需人工验证 | 启动应用，按 ⌘1-4 确认正确切换 |
| 连接状态视觉清晰 | UI-03 | 视觉效果需人工判断 | 启动应用，观察连接/断开状态变化 |
| 节点列表信息易读 | UI-04 | 布局需人工评估 | 连接网络，检查节点列表显示 |
| 日志颜色区分 | UI-05 | 颜色感知需人工验证 | 查看日志，确认 ERROR/WARN/INFO 颜色区分明显 |
| 整体视觉协调 | UI-01 | 整体设计需人工评估 | 浏览全部页面，确认视觉一致 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
