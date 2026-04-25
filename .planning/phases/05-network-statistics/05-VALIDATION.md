---
phase: 5
slug: network-statistics
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-25
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift) |
| **Config file** | EasyTierGUITests (Xcode test target) |
| **Quick run command** | `xcodebuild test -scheme EasyTierGUI -destination 'platform=macOS' -only-testing:EasyTierGUITests/TopologyTests` |
| **Full suite command** | `xcodebuild test -scheme EasyTierGUI -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Build + quick topology test
- **After every plan wave:** Full test suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-01-01 | 01 | 1 | STAT-01 | — | N/A | unit | `xcodebuild test -only-testing:PeerInfoTests/testLatencyDisplay` | ❌ W0 | ⬜ pending |
| 5-01-02 | 01 | 1 | STAT-03 | — | N/A | unit | `xcodebuild test -only-testing:TopologyTests/testCanvasRenders` | ❌ W0 | ⬜ pending |
| 5-02-01 | 02 | 1 | STAT-05 | — | N/A | unit | `xcodebuild test -only-testing:PeerInfoTests/testStaleIndication` | ❌ W0 | ⬜ pending |
| 5-02-02 | 02 | 1 | STAT-04 | — | N/A | unit | `xcodebuild test -only-testing:ProcessViewModelTests/testPeerPollingInterval` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `EasyTierGUITests/TopologyTests.swift` — test stubs for topology canvas
- [ ] `EasyTierGUITests/PeerInfoTests.swift` — test stubs for stale data indication
- [ ] XCTest framework already exists in project

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Topology interaction (hover/click) | STAT-03 | Canvas gesture testing requires UI automation | 1. Run app, connect to network 2. Expand topology view 3. Hover over nodes, verify highlight |
| Real network latency display | STAT-01 | Requires live EasyTier network | 1. Start EasyTier network 2. Connect to peers 3. Verify latency values appear in list and topology |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
