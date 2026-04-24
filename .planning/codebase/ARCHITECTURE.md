# Architecture

**Analysis Date:** 2025-04-24

## Pattern Overview

**Overall:** Desktop GUI Application with MVVM Pattern

**Key Characteristics:**
- Single-window macOS app with sidebar navigation
- State-driven UI via Combine `@Published` properties
- Multi-network concurrent support (each config has independent runtime)
- Hybrid SwiftUI/AppKit for system integration
- Privileged subprocess management for network operations

## Layers

### View Layer

**Purpose:** Present UI and handle user interactions

**Contains:** SwiftUI views, view-specific state, presentation logic

**Key Files:**
- `EasyTierGUI/Views/ContentView.swift` - Main window shell with sidebar
- `EasyTierGUI/Views/ConnectionView.swift` - Network configuration form
- `EasyTierGUI/Views/PeersView.swift` - Connected nodes table
- `EasyTierGUI/Views/LogView.swift` - Log stream display
- `EasyTierGUI/Views/SettingsView.swift` - Preferences and updates

**Depends on:** `ProcessViewModel` via `@EnvironmentObject`

### ViewModel Layer

**Purpose:** Coordinate between UI and services, manage app state

**Key Components:**

**ProcessViewModel** (`EasyTierGUI/Services/ProcessViewModel.swift`):
- Singleton `@MainActor` class
- Manages array of `NetworkRuntime` instances
- Coordinates multi-network operations
- Handles global status aggregation

**NetworkRuntime** (`EasyTierGUI/Services/ProcessViewModel.swift`):
- Per-network runtime state
- Wraps `EasyTierService` instance
- Publishes connection status, peers, errors
- Manages peer polling timer

**Depends on:** Services layer, Models layer

### Service Layer

**Purpose:** Encapsulate external interactions and business logic

**Key Components:**

**EasyTierService** (`EasyTierGUI/Services/EasyTierService.swift`):
- `Process` lifecycle management
- Privileged execution coordination
- Log parsing and streaming
- Peer fetching via easytier-cli

**ConfigManager** (`EasyTierGUI/Services/ConfigManager.swift`):
- Configuration CRUD operations
- JSON persistence with debouncing
- Port conflict resolution
- Import/export functionality

**BinaryManager** (`EasyTierGUI/Services/BinaryManager.swift`):
- Core version detection
- GitHub release checking
- Download and installation
- Path resolution (bundled vs user-installed)

**MenuBarManager** (`EasyTierGUI/Services/MenuBarManager.swift`):
- NSStatusBar integration
- Status menu construction
- Connection status display

**GitHubReleaseService** (`EasyTierGUI/Services/GitHubReleaseService.swift`):
- GitHub API client
- Release asset downloading
- Cache management

**Depends on:** Models layer, System layer

### System Layer

**Purpose:** Interface with macOS system APIs

**PrivilegedExecutor** (`EasyTierGUI/Services/PrivilegedExecutor.m`):
- Objective-C bridging to Authorization Services
- Cached authorization reference
- Command execution with privileges

**AppDelegate** (`EasyTierGUI/EasyTierGUIApp.swift`):
- NSApplicationDelegate implementation
- Window lifecycle management
- Dock icon visibility toggle
- Root privilege detection

**Depends on:** macOS Security.framework, AppKit

### Model Layer

**Purpose:** Define data structures

**Key Types** (`EasyTierGUI/Models/Models.swift`):
- `EasyTierConfig` - Network configuration (Codable)
- `PeerInfo` - Connected node information
- `LogEntry` - Parsed log line
- `NetworkStatus` - Connection state enum
- `TunConfig` - TUN device settings

**BinaryVersion** (`EasyTierGUI/Models/BinaryVersion.swift`):
- GitHub release metadata
- Version comparison logic

## Data Flow

### Network Connection Flow

1. **User clicks Connect** (`ConnectionView.swift`)
2. **ProcessViewModel.connect()** validates and delegates
3. **NetworkRuntime.connect()** creates service context
4. **EasyTierService.start()** checks authorization
5. **PrivilegedExecutor** executes easytier-core with sudo
6. **Process** stdout parsed for logs
7. **Timer** triggers periodic peer fetching
8. **Published properties** update UI via SwiftUI bindings

### Configuration Persistence Flow

1. **User edits config** (`ConnectionView.swift`)
2. **ConfigManager** updates `@Published configs`
3. **Debounced save** (0.5s) to background queue
4. **Atomic JSON write** to `~/Library/Application Support/EasyTierGUI/`
5. **ProcessViewModel** syncs runtimes to new config list

### Update Check Flow

1. **Daily timer** triggers (14:00 local time)
2. **BinaryManager** calls GitHub API
3. **GitHubReleaseService** fetches latest release
4. **Version comparison** against installed core
5. **Update state published** -> `SettingsView` shows banner
6. **User initiates download** -> Background download + install

## Key Abstractions

### Service Pattern

Purpose: Encapsulate external resource management

Examples:
- `EasyTierService` - Manages external process
- `GitHubReleaseService` - HTTP API client
- `BinaryManager` - File system + network resource

Pattern: Singleton or shared instance, ObservableObject for UI binding

### Repository Pattern (ConfigManager)

Purpose: Abstract data persistence

Implementation:
- CRUD operations on configs array
- Private persistence queue for I/O
- Debounced saves to batch rapid changes

### Command Pattern (Privileged Execution)

Purpose: Execute privileged operations safely

Implementation:
- Authorization reference cached at app start
- Single prompt, multiple executions
- Commands run via `/bin/sh -c` wrapper

## Entry Points

### App Launch

**Location:** `EasyTierGUIApp.swift` - `@main struct EasyTierGUIApp`

**Flow:**
1. `AppDelegate.applicationDidFinishLaunching`
2. Clean orphaned processes
3. Setup menu bar
4. Check/request authorization
5. Show main window

### CLI Build

**Location:** `build.sh`

**Flow:**
1. Download EasyTier binaries (if needed)
2. `xcodebuild` Universal Binary
3. Embed binaries in app bundle
4. Verify architectures

## Error Handling

**Strategy:** Throw descriptive errors, catch at UI layer, present user-friendly alerts

**Patterns:**
- Domain-specific errors: `EasyTierError`, `InstallError`
- UI displays `errorMessage` from ViewModels
- Privileged operations fail gracefully with auth prompts

## Cross-Cutting Concerns

### Logging

Approach: In-app log viewer, not system logging

Implementation:
- `LogEntry` struct with timestamp, level, message
- `maxLogEntries = 100` circular buffer
- Color-coded by level (red=error, orange=warn, blue=info)

### State Management

Approach: Combine framework with `@Published`

Patterns:
- ViewModels are `@MainActor` for thread safety
- `AnyCancellable` stored to maintain subscriptions
- Multiple runtimes keyed by config ID

### Security

Approach: Least privilege with explicit elevation

Implementation:
- Authorization Services for root operations only
- No credential storage (passwords entered per session)
- File permissions verified before execution

---

*Architecture analysis: 2025-04-24*
*Update when major patterns change*
