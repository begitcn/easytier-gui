# Integrations

**Analysis Date:** 2025-04-24

## External Services

### GitHub Releases API

**Purpose:** Download and update EasyTier core binaries

**Integration:** `GitHubReleaseService.swift`

**API Endpoints:**
- `GET https://api.github.com/repos/EasyTier/EasyTier/releases/latest` - Fetch latest release info
- `GET https://github.com/EasyTier/EasyTier/releases/download/{version}/easytier-macos-{arch}-{version}.zip` - Download binaries

**Rate Limiting:**
- Uses redirect-based version detection first (avoids API rate limits)
- Falls back to API if redirect fails
- Implements caching to reduce API calls

**Error Handling:**
- Graceful degradation with hardcoded fallback version (v2.4.5)
- User-facing error messages in Chinese

### EasyTier Core (Subprocess)

**Purpose:** P2P VPN networking daemon

**Integration:** `EasyTierService.swift`

**Command Invocation:**
```bash
# Normal launch via Authorization Services
easytier-core -i <network_name> -s <server_uri> --hostname <name> ...

# Version check
easytier-core -V
```

**Communication:**
- Process stdout/stderr parsing for logs
- Periodic `easytier-cli` calls via RPC portal for peer info
- File-based log reading for privileged mode

**Lifecycle:**
- App launches with authorization prompt
- Core process started/stopped per network config
- Cleanup on app termination (`applicationWillTerminate`)

### macOS Authorization Services

**Purpose:** Privilege escalation for TUN device creation

**Integration:** `PrivilegedExecutor.m`

**API:** `Security.framework` - `AuthorizationCreate`, `AuthorizationCopyRights`, `AuthorizationExecuteWithPrivileges`

**Implementation:**
- Single authorization session cached during app lifetime
- Password prompt shown once at startup
- Commands executed via `/bin/sh -c` wrapper

## Local System Integration

### File System

**App Support Directory:**
- `~/Library/Application Support/EasyTierGUI/` - Config persistence
- `~/Library/Application Support/EasyTierGUI/bin/` - User-installed core updates

**Temporary Files:**
- Downloaded ZIPs extracted to `NSTemporaryDirectory()`
- Log files for privileged mode

### UserDefaults

**Persistence:**
- `showDockIcon` - Dock visibility preference
- `showMenuBar` - Menu bar icon preference
- `enableLogMonitoring` - Log monitoring toggle
- `autoConnectOnLaunch` - Auto-connect setting
- `easytierInstalledVersion` - Current core version tracking
- `easytierSkipVersion` - Skipped update version

### Menu Bar Integration

**Integration:** `MenuBarManager.swift`

**System APIs:**
- `NSStatusBar` - Status item creation
- `NSStatusItem` - Menu bar icon and menu
- Status updates based on network connection state

### Window Management

**Integration:** `AppDelegate.swift` (in `EasyTierGUIApp.swift`)

**Features:**
- `NSApp.setActivationPolicy(.regular/.accessory)` - Dock icon toggle
- Window delegate for close handling
- "Close to menu bar" behavior when Dock hidden

## Data Persistence

### Configuration Storage

**Format:** JSON files

**Files:**
- `configs.json` - Array of `EasyTierConfig` objects
- `active_index.json` - Active config index

**Schema:**
```swift
EasyTierConfig: Codable {
    id: UUID
    name: String
    networkName: String
    networkPassword: String
    serverURI: String
    hostname: String
    enableLatencyFirst: Bool
    enablePrivateMode: Bool
    enableMagicDNS: Bool
    enableMultiThread: Bool
    enableKCP: Bool
    listenPort: Int
    rpcPortalPort: Int
    tunConfig: TunConfig
    useDHCP: Bool
}
```

**Persistence Strategy:**
- Debounced saves (0.5s delay)
- Background queue for I/O
- Atomic file writes

## Network Integration

### TUN Device

**Purpose:** Virtual network interface for VPN traffic

**Requirements:**
- Root privileges (via Authorization Services)
- Exclusive port binding (listenPort, rpcPortalPort)

**Port Allocation:**
- Listen: 11010+ (auto-increment on conflict)
- RPC Portal: 15888+ (auto-increment on conflict)

---

*Integrations documented: 2025-04-24*
*Update when new services added*
