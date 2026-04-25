# Architecture Research

**Domain:** macOS VPN Management Application (EasyTier GUI)
**Researched:** 2026/04/24
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Views Layer                                  │
├─────────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────┐ │
│  │ConnectionView│  │  PeersView   │  │SettingsView  │  │StatsView│ │
│  │   (Form)     │  │   (Table)    │  │  (Prefs)     │  │(NEW)    │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────┬────┘ │
│         │                 │                 │                │       │
├─────────┴─────────────────┴─────────────────┴────────────────┴───────┤
│                     ViewModel Layer (ProcessViewModel)               │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  @MainActor coordinator: configs, runtimes, services           │ │
│  │  - configManager, easytierCoreExists, connect/disconnect       │ │
│  │  - NEW: statsService, backupService, quickConnectService       │ │
│  └────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────┤
│                      Service Layer                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │ConfigManager│  │EasyTierSvc  │  │BinaryMgr    │  │MenuBarMgr │  │
│  │(Persistence)│  │(Process)    │  │(Updates)    │  │(System UI)│  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────┘  └───────────┘  │
├─────────┴────────┬───────┴──────────────────────────────────────────┤
│              NEW Feature Services                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │NetworkStats  │  │  Backup      │  │ QuickConnect │               │
│  │  Service     │  │  Service     │  │  Service     │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
├─────────────────────────────────────────────────────────────────────┤
│                        Data Layer                                    │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐     │
│  │ ~/Library/AppSupport │  │  ~/Library/Preferences           │     │
│  │  EasyTierGUI/        │  │  cn.begitcn.EasyTierGUI.plist    │     │
│  │    configs.json      │  │    (AppStorage)                  │     │
│  │    active_index.json │  └──────────────────────────────────┘     │
│  └──────────────────────┘                                            │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| ProcessViewModel | Central coordinator, manages NetworkRuntimes | @MainActor class, @Published props |
| ConfigManager | Network config CRUD, JSON persistence | Already has import/export (lines 152-176) |
| EasyTierService | easytier-core subprocess, peer polling | Process management |
| NetworkRuntime | Per-config runtime state | @MainActor ObservableObject |
| **NetworkStatsService** | NEW: Network stats collection | Timer-based polling, stats parsing |
| **BackupService** | NEW: Full backup/restore | JSON archive + FileManager |
| **QuickConnectService** | NEW: Desktop shortcuts | NSWorkspace, URL scheme |

## Recommended Project Structure

```
EasyTierGUI/
├── Models/
│   ├── Models.swift           # Existing: EasyTierConfig, PeerInfo, etc.
│   ├── NetworkStats.swift     # NEW: Bandwidth, latency, topology models
│   └── BackupManifest.swift   # NEW: Backup metadata structure
├── Services/
│   ├── ProcessViewModel.swift # Existing: Central coordinator (+ new services)
│   ├── ConfigManager.swift    # Existing: Config CRUD
│   ├── EasyTierService.swift  # Existing: Core process management
│   ├── NetworkStatsService.swift   # NEW: Stats aggregation
│   ├── BackupService.swift         # NEW: Backup/restore operations
│   └── QuickConnectService.swift   # NEW: Desktop shortcuts
├── Views/
│   ├── ContentView.swift      # Existing: Main layout + new StatsView tab
│   ├── ConnectionView.swift   # Existing: Network config UI
│   ├── PeersView.swift        # Existing: Peer list
│   ├── LogView.swift          # Existing: Log viewer
│   ├── SettingsView.swift     # Existing: App settings (add backup panel)
│   ├── StatsView.swift        # NEW: Network statistics UI
│   └── Components/
│       ├── StatsChart.swift   # NEW: Bandwidth/latency charts
│       └── BackupPanel.swift  # NEW: Backup restore dialog
```

### Structure Rationale

- **NetworkStatsService:** Isolate stats logic from ProcessViewModel to keep coordinator clean
- **BackupService:** Single responsibility for all backup/restore operations
- **QuickConnectService:** Uses low-level macOS APIs (NSWorkspace), separate from UI
- **NetworkStats model:** Pure data struct, no business logic
- **Existing code stays as-is:** Config import/export already exists in ConfigManager

## Architectural Patterns

### Pattern 1: Service Layer Extension

**What:** Add new service classes for each feature, accessed via ProcessViewModel
**When to use:** When new features are orthogonal to existing functionality
**Trade-offs:**
- Pros: Clean separation, testable, follows existing patterns
- Cons: More classes to manage

**Example:**
```swift
// ProcessViewModel adds service dependencies
@MainActor
class ProcessViewModel: ObservableObject {
    let statsService = NetworkStatsService()
    let backupService = BackupService()
    let quickConnectService = QuickConnectService()
    
    // Stats are exposed via runtime
    func getNetworkStats(for configID: UUID) -> NetworkStats? {
        statsService.stats[configID]
    }
}
```

### Pattern 2: Stats Polling via Timer

**What:** Periodically query easytier-cli for network statistics
**When to use:** When source of truth is external CLI process
**Trade-offs:**
- Pros: Simple, real-time data
- Cons: Polling overhead, potential lag

**Example:**
```swift
class NetworkStatsService: ObservableObject {
    @Published var stats: [UUID: NetworkStats] = [:]
    private var pollTimer: Timer?
    
    func startPolling(rpcPortalPort: Int, configID: UUID) {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchStats(port: rpcPortalPort, id: configID)
        }
    }
}
```

### Pattern 3: Backup Archive Format

**What:** JSON manifest + embedded config JSON in a zip archive
**When to use:** When backup needs to include multiple file types
**Trade-offs:**
- Pros: Single file, versioned, extensible
- Cons: More complex than single-file export

**Example:**
```swift
struct BackupManifest: Codable {
    let version: String  // "1.1"
    let createdAt: Date
    let appVersion: String
    let configs: [EasyTierConfig]
    let settings: AppSettings  // @AppStorage properties
}
```

### Pattern 4: URL Scheme for Quick Connect

**What:** Register custom URL scheme for deep linking
**When to use:** Desktop shortcuts need to launch app with parameters
**Trade-offs:**
- Pros: Standard macOS mechanism, works with .inetloc
- Cons: Requires app to be registered as handler

**Example:**
```swift
// Register in Info.plist: CFBundleURLTypes -> easystiergui://
// Handle in AppDelegate:
func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
        if url.scheme == "easytiergui" {
            handleQuickConnect(url: url)
        }
    }
}
```

## Data Flow

### Request Flow

```
[User clicks "Stats" tab]
    ↓
[ContentView] → [ProcessViewModel.getNetworkStats()]
    ↓
[NetworkStatsService] → [Timer callback] → [easyytier-cli JSON]
    ↓
[ProcessViewModel] ← [Publish new stats]
    ↓
[StatsView] ← [@ObservedObject refresh]
```

### Backup/Restore Flow

```
[User clicks "Backup"]
    ↓
[SettingsView] → [ProcessViewModel.backupService.backup(to:)]
    ↓
[BackupService]
    ├─► Read configs from ConfigManager
    ├─► Read settings from UserDefaults
    ├─► Create BackupManifest
    ├─► Serialize to JSON
    ├─► Use NSOpenPanel for destination
    └─► Write ZIP archive
```

### Quick Connect Flow

```
[User clicks .inetloc shortcut]
    ↓
[NSWorkspace opens URL]
    ↓
[AppDelegate receives URL: easytiergui://connect?config=<uuid>]
    ↓
[QuickConnectService parses URL]
    ↓
[ProcessViewModel.connect(configID:)]
    ↓
[NetworkRuntime.connect()]
```

### State Management

```
┌─────────────────┐
│ ProcessViewModel│ ← Central coordinator (existing)
└────────┬────────┘
         │
    ┌────┴────┬──────────┬──────────────┐
    ↓         ↓          ↓              ↓
[ConfigMan] [StatsSvc] [BackupSvc] [ShortcutSvc]
    │         │          │              │
    └─────────┴──────────┴──────────────┘
              ↓
    [EasyTierService] → easytier-core process
```

### Key Data Flows

1. **Stats Collection:** Runtime calls EasyTierService → parses CLI output → NetworkStatsService publishes → Views react
2. **Backup:** User triggers → BackupService reads configs + UserDefaults → creates ZIP → saves to user-chosen location
3. **Restore:** User selects file → BackupService extracts → validates manifest → updates ConfigManager + UserDefaults
4. **Quick Connect:** User clicks .inetloc → QuickConnectService parses → launches app with config ID argument

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| easytier-cli | Pipe stdout JSON via Process | Already exists in EasyTierService |
| NSWorkspace | Launch URL scheme for shortcuts | Need to register URL scheme |
| FileManager | Standard i/o for backup | Use dispatch queues |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| ProcessViewModel ↔ StatsService | @Published, direct method | StatsService injected into VM |
| StatsService ↔ EasyTierService | Callback/closure | Stats polling uses RPC port |
| BackupService ↔ ConfigManager | Direct method calls | BackupService imports/exports |
| App ↔ Quick Connect | URL scheme + args | `easytiergui://connect?config=<uuid>` |

### Existing Features vs New Features

| Feature | Location | Status |
|---------|----------|--------|
| Config import/export | ConfigManager lines 152-176 | ✅ Already implemented |
| Auto-connect on launch | SettingsView line 19: `@AppStorage("autoConnectOnLaunch")` | ✅ Already implemented |

| Feature | New Component | Priority |
|---------|---------------|----------|
| Network stats (topology, latency, bandwidth) | NetworkStatsService + StatsView | P1 |
| Advanced settings UI | ConnectionView enhancement | P2 |
| Settings backup/restore | BackupService + SettingsView panel | P2 |
| Quick-connect shortcuts | QuickConnectService + URL scheme | P3 |

## Build Order

Given dependencies:

```
1. NetworkStats model          ← Pure data, no deps
2. NetworkStatsService         ← Depends on model
3. StatsView                   ← Depends on service
4. BackupManifest + BackupSvc  ← Uses ConfigManager
5. SettingsView + BackupPanel  ← Uses BackupService
6. QuickConnectService         ← Needs URL scheme registration
7. App entry point update      ← Handle URL schemes
```

**Recommended Order:**

**Phase 1: Network Statistics**
1. Add `NetworkStats.swift` model
2. Add `NetworkStatsService.swift` service
3. Add `StatsView.swift` view
4. Add "Stats" tab to `ContentView`

**Phase 2: Backup/Restore**
1. Add `BackupManifest.swift` model
2. Add `BackupService.swift` service
3. Add backup panel to `SettingsView.swift`

**Phase 3: Quick Connect**
1. Add `QuickConnectService.swift`
2. Register URL scheme in Info.plist
3. Handle URL in `EasyTierGUIApp.swift`

## Anti-Patterns

### Anti-Pattern 1: Stats in NetworkRuntime

**What people do:** Add stats properties directly to NetworkRuntime
**Why it's wrong:** Violates single responsibility, bloats the coordinator class
**Do this instead:** Use NetworkStatsService as separate service

### Anti-Pattern 2: Global @AppStorage everywhere

**What people do:** Store all settings in @AppStorage without abstraction
**Why it's wrong:** Hard to backup/restore, no validation
**Do this instead:** Create AppSettings Codable struct stored in ConfigManager directory

### Anti-Pattern 3: Blocking UI on backup/restore

**What people do:** Perform file I/O on main thread
**Why it's wrong:** Freezes UI, poor UX
**Do this instead:** All file operations async with Task, show progress indicator

### Anti-Pattern 4: Duplicate Import/Export

**What people do:** Implement import/export again instead of using ConfigManager
**Why it's wrong:** Duplication, inconsistency
**Do this instead:** Reuse ConfigManager.exportConfig/importConfig for single configs

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|-------------------------|
| 0-1k users | Single ProcessViewModel is fine |
| 1k-100k users | Consider caching stats, lazy loading in Views |
| 100k+ users | Consider background sync service |

### Scaling Priorities

1. **First bottleneck:** Stats polling on main thread → Solution: Background queue + throttling
2. **Second bottleneck:** Large peer list rendering → Solution: LazyVStack with pagination
3. **Third bottleneck:** Backup file size → Solution: Compress with ZIP (already planned)

## Sources

- [Swift Concurrency - The Complete Guide](https://www.hackingwithswift.com/swift/5.5/actors)
- [MainActor usage in SwiftUI - SwiftLee](https://www.avanderlee.com/concurrency/mainactor-dispatchqueue-main/)
- [Apple Developer Documentation - MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [macOS URL Schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)

---
*Architecture research for: EasyTier GUI v1.1 Feature Enhancement*
*Researched: 2026/04/24*
