# Stack Research

**Domain:** macOS SwiftUI App Feature Enhancement
**Researched:** 2026-04-24
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift Charts | Native (macOS 13+, optimized for 14+) | Network stats visualization (topology, latency, bandwidth) | Native Apple framework, no external dependencies, optimized for SwiftUI |
| SMAppService | Native (macOS 13+) | Auto-connect on startup (Login Items) | Replaces deprecated LSSharedFileList, official Apple API |
| NSWorkspace | Native (AppKit) | Quick-connect desktop shortcuts | Create .app bundles or open URLs programmatically |
| FileWrapper | Native (Foundation) | Backup/restore with directory structures | Handles file system objects for comprehensive backups |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| (None required) | — | — | All features use native frameworks |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 15+ | SwiftUI + Swift Charts preview | Use Canvas for real-time chart preview |
| easytier-cli | Peer stats retrieval | Poll for latency/bandwidth data (existing) |

## Existing Capabilities (Reuse)

| Feature | Existing Implementation | Notes |
|---------|------------------------|-------|
| Config import/export | `ConfigManager.exportConfig/importConfig` (lines 152-176) | Already implemented, just add UI |
| Config backup/restore | `ConfigManager.exportAllConfigs/importConfigs` | Extend to include app preferences |
| Advanced settings model | `EasyTierConfig` struct fields | Already exists: enableLatencyFirst, enablePrivateMode, etc. |
| Peer info polling | `EasyTierService.pollPeers()` | Use for stats data source |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Charts library (第三方) | Not needed - Swift Charts is native and sufficient | Swift Charts |
| Login Items (deprecated LSSharedFileList) | Deprecated since macOS 13 | SMAppService |
| Third-party JSON libraries | Foundation.JSONEncoder/Decoder already used | Native Codable |
| External graph visualization (e.g., D3) | Overkill for simple network stats | Swift Charts |

## Stack Patterns by Variant

**If network stats require real-time streaming:**
- Use Swift Charts with `@State` array append + timer
- Throttle updates to 1-2 Hz to avoid UI overload

**If quick-connect needs .app bundle shortcuts:**
- Use NSWorkspace to create minimal .app in ~/Applications/
- Or use `fsevents`/`NSWorkspace` to open deep-link URLs

**If backup needs include app preferences:**
- Extend ConfigManager to export UserDefaults keys
- Use FileWrapper for directory-based backup (configs + preferences.json)

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| Swift Charts | macOS 13+ (basic), macOS 14+ (full features) | EasyTierGUI min is macOS 14, fully supported |
| SMAppService | macOS 13+ | EasyTierGUI min is macOS 14, fully supported |
| NSWorkspace | All macOS versions | No compatibility concerns |

## Sources

- Apple Swift Charts Documentation — https://developer.apple.com/documentation/charts
- Apple SMAppService Documentation — https://developer.apple.com/documentation/servicemanagement
- Apple NSWorkspace Documentation — https://developer.apple.com/documentation/appkit/nsworkspace
- Project existing code — ConfigManager.swift (import/export), Models.swift (config fields)

---

*Stack research for: EasyTier GUI v1.1 Feature Enhancement*
*Researched: 2026-04-24*
