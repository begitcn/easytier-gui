# Roadmap: EasyTier GUI

**Created:** 2025-04-24
**Mode:** yolo
**Core Value:** 程序稳定运行，交互响应及时，内存长期稳定

---

## Milestones

- ✅ **v1.0 Performance Optimization** — Phases 1-3 (shipped 2026-04-24)
- 🔄 **v1.1 Feature Enhancement** — Phases 4-7 (in progress)

---

## Phases

<details>
<summary>✅ v1.0 Performance Optimization (Phases 1-3) — SHIPPED 2026-04-24</summary>

- [x] Phase 1: 响应性与交互反馈 (5/5 plans) — completed 2026-04-24
- [x] Phase 2: 内存与稳定性 (5/5 plans) — completed 2026-04-24
- [x] Phase 3: UI 优化 (5/5 plans) — completed 2026-04-24

**Key Accomplishments:**
- Eliminated main thread blocking with async initialization
- Immediate visual feedback on all button actions
- Toast notifications replacing blocking alerts
- Robust process management with graceful shutdown
- macOS HIG compliant UI with 8pt grid spacing

</details>

---

<details>
<summary>🔄 v1.1 Feature Enhancement (Phases 4-7) — IN PROGRESS</summary>

### Phase 4: Config Import/Export Foundation
**Requirements:** CONF-01, CONF-02, CONF-03, CONF-04, CONF-05, CONF-06
**Status:** Pending

- Config export service with sensitive data redaction
- Config import service with schema validation
- Export/import UI with file picker

### Phase 5: Network Statistics
**Requirements:** STAT-01, STAT-02, STAT-03, STAT-04, STAT-05
**Status:** Pending

- NetworkStats/PeerStats models
- NetworkStatsService with 2-second polling
- StatsView with latency, bandwidth, topology

### Phase 6: Auto-Connect & Settings Backup
**Requirements:** AUTO-01, AUTO-02, AUTO-03, AUTO-04, AUTO-05, SETT-01, SETT-02, SETT-03
**Status:** Pending

- SMAppService integration for login items
- Last-used config persistence
- Network readiness check with delay
- BackupService for full config/preferences backup

### Phase 7: Advanced Settings & Quick-Connect
**Requirements:** SETT-04, SETT-05, SETT-06, QUICK-01, QUICK-02, QUICK-03, QUICK-04, QUICK-05
**Status:** Pending

- Advanced protocol/logging/network options UI
- Menu bar quick-connect submenu
- URL scheme registration with validation

</details>

---

## Progress

| Phase | Milestone | Requirements | Status |
|-------|-----------|--------------|--------|
| 4 | Config I/O | CONF-01~CONF-06 | Pending |
| 5 | Network Stats | STAT-01~STAT-05 | Pending |
| 6 | Auto-Connect & Backup | AUTO-01~AUTO-05, SETT-01~SETT-03 | Pending |
| 7 | Advanced Settings & Quick-Connect | SETT-04~SETT-06, QUICK-01~QUICK-05 | Pending |

**v1.1 Coverage:** 27/27 requirements (100%)

---

*Roadmap created: 2025-04-24*
*v1.0 shipped: 2026-04-24*
*v1.1 started: 2026-04-24*
