# Project Research Summary

**Project:** EasyTier GUI v1.1 Feature Enhancement
**Domain:** macOS VPN Network Management Application
**Researched:** 2026-04-24
**Confidence:** HIGH

## Executive Summary

EasyTier GUI is a native macOS VPN management application that provides a graphical interface for EasyTier (a P2P VPN tool). The v1.1 enhancement focuses on adding productivity features that users expect from any network management app. Research indicates the recommended approach uses native Apple frameworks (Swift Charts, SMAppService, NSWorkspace) to implement config import/export, auto-connect on startup, and network statistics visualization. The key risk is implementing features without proper validation and security measures—particularly around credential handling in config exports and URL scheme security for quick-connect features. Following the phased implementation plan will mitigate these risks while delivering features in priority order.

## Key Findings

### Recommended Stack

**Core technologies:**
- **Swift Charts** — Network stats visualization (bandwidth, latency, topology) — Native Apple framework, no external dependencies, optimized for SwiftUI on macOS 14+
- **SMAppService** — Auto-connect on startup (Login Items) — Official Apple API replacing deprecated LSSharedFileList, macOS 13+ support
- **NSWorkspace** — Quick-connect desktop shortcuts — Native AppKit for creating app aliases or opening URLs programmatically
- **FileWrapper** — Backup/restore with directory structures — Foundation framework for comprehensive backup handling

No external libraries required—all features use native Apple frameworks already compatible with the project's macOS 14.0 minimum target.

### Expected Features

**Must have (table stakes):**
- **Config import/export** — Share configs between machines, create backups — Already partially implemented in ConfigManager, needs UI enhancement
- **Auto-connect on startup** — Convenience for always-on VPN — Uses SMAppService, needs integration with Settings
- **Settings backup/restore** — Full config portability — Reuses import/export, extends to include app preferences

**Should have (competitive):**
- **Network statistics** — Show latency, bandwidth, peer count — Requires easytier-cli integration with periodic polling
- **Advanced settings** — Power user customization (protocol, logging, MTU) — Extends existing EasyTierConfig model
- **Quick-connect menu** — One-click connect from menu bar — Uses NSWorkspace and URL scheme

**Defer (v2+):**
- Bandwidth visualization (sparkline graph) — High complexity, lower user value
- Network topology visualization — Requires extensive CLI integration
- Desktop aliases for quick connect — macOS doesn't have native desktop shortcuts

### Architecture Approach

The recommended architecture extends the existing MVVM pattern by adding three new service classes accessed via ProcessViewModel:
1. **NetworkStatsService** — Timer-based polling of easytier-cli for latency/bandwidth data, publishes to views via @Published
2. **BackupService** — Full backup/restore using JSON archive format with versioning metadata
3. **QuickConnectService** — URL scheme handling for desktop shortcuts (`easytiergui://connect?config=<uuid>`)

New components include NetworkStats.swift and BackupManifest.swift models, plus StatsView.swift and BackupPanel.swift view components. The existing ConfigManager already has import/export methods (lines 152-176) that should be reused rather than duplicated.

### Critical Pitfalls

1. **Config Export Includes Sensitive Data** — Exporting configs with plaintext passwords/tokens exposes credentials. **How to avoid:** Mark sensitive fields, implement Codable that redacts for export, add "Include credentials" toggle defaulting to off.

2. **Real-time Stats Polling Causes Performance Degradation** — Polling too frequently (e.g., 100ms) exhausts CPU and causes UI stuttering. **How to avoid:** Use 1-2 second polling interval, batch all stat queries into single CLI call, use Combine throttling.

3. **Stats Display Shows Stale Data Without Indication** — UI shows old values when disconnected without visual feedback. **How to avoid:** Display "last updated" timestamp, show disconnected state with dimmed stats, use color indicators for stale data.

4. **Config Import Without Schema Validation** — Importing invalid JSON crashes app or causes undefined behavior. **How to avoid:** Validate schema version, check required fields, provide clear error messages.

5. **Auto-connect Runs Before Network is Ready** — App launches at login and immediately fails because network interfaces aren't ready. **How to avoid:** Add 3-5 second delay before auto-connect, monitor network availability, show "Waiting for network..." status.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Config Foundation
**Rationale:** Config import/export is the foundation for backup/restore and uses existing ConfigManager code—lowest implementation cost with highest user value.
**Delivers:** Config export/import UI with file picker, schema validation, sensitive data redaction
**Addresses:** FEAT-01 (Config import/export)
**Avoids:** Pitfall #1 (schema validation), Pitfall #2 (sensitive data exposure)

### Phase 2: Network Statistics
**Rationale:** Stats visualization requires new service layer and CLI integration—most complex feature, should be validated early.
**Delivers:** NetworkStats model, NetworkStatsService with 2-second polling, StatsView with peer latency display
**Addresses:** FEAT-02 (Peer list with latency), FEAT-02 (Connection status with peer count)
**Avoids:** Pitfall #3 (polling performance), Pitfall #4 (stale data)

### Phase 3: Auto-Connect & Backup
**Rationale:** Both use UserDefaults persistence—complementary implementations, share preferences storage pattern.
**Delivers:** Auto-connect toggle in Settings using SMAppService, settings backup/restore with BackupService
**Addresses:** FEAT-04 (Auto-connect), FEAT-06 (Settings backup/restore)
**Avoids:** Pitfall #5 (network not ready), Pitfall #10 (backup excludes state), Pitfall #12 (restore overwrite)

### Phase 4: Advanced Settings & Quick Connect
**Rationale:** Power user features that enhance usability but have security considerations requiring careful implementation.
**Delivers:** Advanced settings UI (protocol, logging, MTU), menu bar quick-connect menu, URL scheme registration
**Addresses:** FEAT-03 (Advanced settings UI), FEAT-05 (Quick-connect menu)
**Avoids:** Pitfall #6 (debug options exposed), Pitfall #8 (URL scheme collision), Pitfall #9 (no confirmation)

### Phase Ordering Rationale

- **Phase 1 first:** Uses existing ConfigManager code, lowest risk, foundation for backup/restore
- **Phase 2 before Phase 3:** Stats service provides data for potential future features; backup is simpler without stats integration
- **Phase 3 before Phase 4:** Auto-connect and backup have fewer security concerns than URL scheme handling
- **Phase 4 last:** Quick-connect has highest security implications (Pitfall #8, #9) and requires careful implementation

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Network Statistics):** Need to verify easytier-cli commands actually return expected JSON format—project source shows CLI exists but exact output format not confirmed
- **Phase 4 (Quick Connect):** URL scheme security requires careful validation of URL parameters to prevent command injection

Phases with standard patterns (skip research-phase):
- **Phase 1:** File picker, JSON serialization—well-documented Apple patterns
- **Phase 3:** SMAppService, backup/restore—standard macOS patterns with clear documentation

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Native Apple frameworks with clear documentation, all compatible with macOS 14+ |
| Features | HIGH | VPN app industry patterns well-established, EasyTier CLI capabilities verified in project source |
| Architecture | HIGH | Follows existing MVVM pattern, adds services following single-responsibility principle |
| Pitfalls | HIGH | Based on common VPN app issues, Apple platform patterns, and existing codebase analysis |

**Overall confidence:** HIGH

### Gaps to Address

- **easy tier-cli JSON output format:** Need to verify actual command output structure during Phase 2 implementation—may need to adjust parsing logic
  - **How to handle:** Create mock data based on project source, validate against actual CLI during integration testing

- **Backup file encryption:** Current plan uses plain JSON—may want password-protected backup for security-conscious users
  - **How to handle:** Start with plain JSON (MVP), add encryption as post-launch enhancement

## Sources

### Primary (HIGH confidence)
- Apple Swift Charts Documentation — https://developer.apple.com/documentation/charts
- Apple SMAppService Documentation — https://developer.apple.com/documentation/servicemanagement
- Apple NSWorkspace Documentation — https://developer.apple.com/documentation/appkit/nsworkspace
- EasyTier GUI v1.0 codebase — ConfigManager.swift (import/export), ProcessViewModel.swift, EasyTierService.swift

### Secondary (MEDIUM confidence)
- WireGuard documentation — `wg show` CLI interface patterns
- OpenVPN configuration profile format — Industry standard for VPN config files
- WWDC 2023: SwiftUI Performance Best Practices — Polling optimization guidance

### Tertiary (LOW confidence)
- EasyTier CLI interface — Based on project source analysis, exact JSON output format needs verification during implementation

---
*Research completed: 2026-04-24*
*Ready for roadmap: yes*
