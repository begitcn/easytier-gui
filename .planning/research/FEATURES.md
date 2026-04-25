# Feature Research: v1.1 Enhancement Features

**Domain:** EasyTier GUI v1.1 - Network Configuration & Productivity Features
**Researched:** 2026-04-24
**Confidence:** HIGH (based on VPN app industry patterns + EasyTier CLI capabilities)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any network management app. Missing these = app feels incomplete.

| Feature | Why Expected | Complexity | Dependencies |
|---------|--------------|------------|--------------|
| Config import/export | Share configs between machines, backup | MEDIUM | Existing ConfigManager, file I/O |
| Auto-connect on startup | Convenience for always-on VPN | LOW | Login item registration, config persistence |
| Connection status feedback | User knows network state | LOW | Already exists in v1.0 |

### Differentiators (Competitive Advantage)

Features that distinguish excellent network apps from adequate ones.

| Feature | Value Proposition | Complexity | Dependencies |
|---------|-------------------|------------|--------------|
| Network stats visualization | Show latency/bandwidth/topology | HIGH | CLI parsing, periodic polling |
| Quick-connect shortcuts | One-click connect from desktop | MEDIUM | App alias/CLI integration |
| Advanced settings | Power user customization | MEDIUM | Extended config model |
| Settings backup/restore | Full config portability | MEDIUM | Export/import all settings |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time bandwidth graph | "Show live speed" | High CPU, excessive UI updates | Periodic sampling (1-2s interval) |
| Auto-connect all networks | "Always connected" | Resource contention, conflicts | Auto-connect last used only |
| Cloud sync | "Access everywhere" | Privacy concerns, complexity | Local backup/restore sufficient |

---

## Feature Analysis

### 1. Config Import/Export

**Expected Behavior:**

| Aspect | Behavior |
|--------|----------|
| Export format | JSON file (human-readable, easy to audit) |
| Export contents | Network name, listen port, peers list, protocol options, advanced settings |
| Credentials | Encrypted or omitted; user explicitly chooses |
| Import behavior | Validate JSON schema, prompt for conflicts (rename vs replace) |
| File extension | `.easytier.json` or `.json` |
| Sharing | Email, AirDrop, iCloud, USB drive |

**Industry Patterns:**

- WireGuard: `wg-quick save` exports config, text-based
- OpenVPN: `.ovpn` profile files (JSON-like structure)
- Tunnelblick: Import via drag-drop of configuration files
- iOS/macOS VPN: `.mobileconfig` for system-level VPN profiles

**EasyTier Specific:**

- EasyTier configs are already JSON in `~/Library/Application Support/EasytierGUI/`
- Can export individual network configs or all at once
- Should exclude runtime state (PID, connection status)

**Complexity:** MEDIUM
- File picker (NSOpenPanel/NSSavePanel)
- JSON serialization/deserialization
- Validation logic
- Duplicate handling UI

---

### 2. Network Statistics

**Expected Behavior:**

| Metric | Source | Update Frequency |
|--------|--------|------------------|
| Peer list | `easytier-cli get-peers` | 3-5 seconds |
| Connection status | Process state + peer count | Real-time |
| Latency | Ping each peer via `easytier-cli` or raw ICMP | 5-10 seconds |
| Bandwidth | Parse `easytier-cli get-statistics` (if available) | 2-5 seconds |
| Uptime | Process start time | Static |

**Visualization Options:**

| View | Description |
|------|-------------|
| Peer table | List peers with latency, bytes sent/received |
| Status indicator | Green/Yellow/Red based on peer count or latency |
| Optional: Mini graph | Sparkline for bandwidth (last 60 seconds) |

**EasyTier CLI Capabilities (to verify):**

```
easytier-cli get-peers        # List connected peers
easytier-cli get-statistics   # Transfer stats (bandwidth)
easytier-cli get-status       # Overall connection status
```

**If CLI doesn't provide stats:** Fall back to parsing process output or makingeducated guesses.

**Complexity:** HIGH (requires CLI integration, periodic polling, UI updates)
- Needs background timer for periodic updates
- Must throttle UI updates to prevent excessive redraws
- Latency measurement requires ICMP ping or CLI support

---

### 3. Advanced Settings

**Expected Behavior:**

| Category | Options |
|----------|---------|
| Protocol | UDP/TCP toggle, port number, encryption level |
| Peer configuration | Allow/disallow specific peers, static peer list |
| Debugging | Log level (verbose/debug/info/warn/error), log file path |
| Network | MTU size, keepalive interval, reconnect behavior |
| Performance | Concurrent connections, buffer sizes |

**UI Implementation:**

- Expandable/collapsible sections in Settings view
- Some options hidden behind "Advanced" toggle
- Tooltips explaining each option

**EasyTier Core Options (to verify):**

- `--protocol (udp|tcp)`
- `--port <number>`
- `--secret <hex>` (for encryption)
- `--log-level (debug|info|warn|error)`
- `--mtu <number>`
- `--keepalive <seconds>`

**Complexity:** MEDIUM
- Extended config model with new fields
- UI for each setting type (toggle, picker, text field)
- Validation (port range, numeric constraints)

---

### 4. Auto-Connect on Startup

**Expected Behavior:**

| Aspect | Behavior |
|--------|----------|
| Enable/Disable | Toggle in Settings |
| Selection | Remember last-used network config |
| Timing | Connect after app launches and user logs in |
| Privileges | Request authorization on first auto-connect |
| Failure handling | Show notification if auto-connect fails |

**Implementation Options:**

| Approach | macOS Version | Complexity |
|----------|---------------|------------|
| SMAppService (Login Item) | 13+ | LOW |
| LaunchAtLogin SwiftUI modifier | 13+ | LOW |
| launchd plist in ~/Library/LaunchAgents | All | MEDIUM |

**User Flow:**

1. User enables "Auto-connect on startup" in Settings
2. App registers as login item via SMAppService
3. On next login, app launches (hidden or visible)
4. App reads "last used config" from UserDefaults
5. Automatically initiates connection

**Complexity:** LOW-MEDIUM
- UserDefaults for persisting preference
- SMAppService API for login item registration
- Auto-connect logic on app launch

---

### 5. Quick-Connect Shortcuts

**Expected Behavior:**

| Aspect | Behavior |
|--------|----------|
| Desktop shortcut | Click to launch app and connect to specific config |
| Menu bar | Right-click menu with list of saved configs |
| Keyboard shortcut | Optional global hotkey (requires Accessibility permission) |
| Script export | Generate shell script for CLI usage |

**Implementation:**

| Method | Pros | Cons |
|--------|------|------|
| App Alias/Alias | Native macOS, easy to create | Limited customization |
| Shell script | Lightweight, fast | Requires terminal for output |
| Menu bar quick menu | Always accessible | Requires app running |

**macOS "Desktop Shortcut" Reality:**

- macOS doesn't have Windows-style desktop shortcuts
- Best approach: Create app alias in ~/.Desktop or use menu bar
- Alternative: Generate a small shell script that calls `easytier-gui --connect <config-id>`

**Complexity:** MEDIUM
- App alias creation (NSAlias)
- Menu bar quick-connect menu
- Command-line interface for background connect

---

### 6. Settings Backup/Restore

**Expected Behavior:**

| Aspect | Behavior |
|--------|----------|
| Backup contents | All network configs + app preferences |
| Backup format | Single JSON file (or zip for multiple files) |
| Backup location | User-selected (NSSavePanel) |
| Restore behavior | Import all configs, prompt for conflicts |
| Selective restore | Option to restore only specific configs |

**Backup File Structure:**

```json
{
  "version": "1.1",
  "timestamp": "2026-04-24T10:00:00Z",
  "configs": [
    {
      "id": "uuid",
      "name": "Home Network",
      "port": 51820,
      "peers": [...],
      "settings": {...}
    }
  ],
  "preferences": {
    "autoConnect": true,
    "lastConfigId": "uuid",
    "checkUpdates": true
  }
}
```

**Complexity:** MEDIUM
- Combine all configs into single export
- JSON serialization with proper encoding
- Import validation and conflict resolution UI

---

## Feature Dependencies

```
Config Import/Export
    └──requires──> JSON serialization (Codable)
    └──requires──> File picker (NSOpenPanel/NSSavePanel)
    └──requires──> Config validation logic

Network Stats
    └──requires──> easytier-cli integration
    └──requires──> Periodic polling (Timer)
    └──requires──> Throttled UI updates

Advanced Settings
    └──requires──> Extended EasyTierConfig model
    └──requires──> Settings UI components
    └──requires──> Validation logic

Auto-Connect
    └──requires──> UserDefaults persistence
    └──requires──> SMAppService (login item)
    └──requires──> Launch logic modification

Quick-Connect Shortcuts
    └──requires──> Menu bar quick menu
    └──requires──> Optional: CLI argument parsing
    └──requires──> Optional: App alias creation

Backup/Restore
    └──requires──> Config import/export (reuses)
    └──requires──> Preferences serialization
    └──requires──> Conflict resolution UI
```

---

## MVP Definition

### Launch With (v1.1)

Minimum viable feature set for acceptable user experience.

- [ ] **FEAT-01**: Config export to JSON file
- [ ] **FEAT-01**: Config import from JSON file with validation
- [ ] **FEAT-04**: Auto-connect toggle in Settings
- [ ] **FEAT-04**: Auto-connect last used network on launch
- [ ] **FEAT-06**: Settings backup to JSON file
- [ ] **FEAT-06**: Settings restore from JSON file

### Add After Validation (v1.1.x)

Features to add once core functionality is verified.

- [ ] **FEAT-02**: Peer list with latency display
- [ ] **FEAT-02**: Connection status with peer count
- [ ] **FEAT-03**: Advanced settings UI (protocol, logging)
- [ ] **FEAT-05**: Menu bar quick-connect menu

### Future Consideration (v2+)

Advanced features after product-market fit.

- [ ] Bandwidth visualization (sparkline graph)
- [ ] Network topology visualization
- [ ] Desktop aliases for quick connect
- [ ] Global keyboard shortcuts

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Config import/export | HIGH | MEDIUM | P1 |
| Auto-connect on startup | HIGH | LOW | P1 |
| Settings backup/restore | HIGH | MEDIUM | P1 |
| Network stats (peers) | MEDIUM | MEDIUM | P2 |
| Advanced settings | MEDIUM | MEDIUM | P2 |
| Quick-connect menu | MEDIUM | MEDIUM | P2 |
| Bandwidth visualization | LOW | HIGH | P3 |
| Desktop shortcuts | LOW | MEDIUM | P3 |

**Priority Key:**
- P1: Must have for v1.1 release
- P2: Should have, improves user experience
- P3: Nice to have, can defer to future

---

## Technical Implementation Notes

### EasyTier CLI Integration

Based on EasyTier project structure, expected CLI commands:

```bash
# Get connected peers
easytier-cli get-peers

# Get network status
easytier-cli get-status

# Get statistics (if available)
easytier-cli get-statistics

# Connect with specific config
easytier-core --config <path>
```

### macOS Login Item API

```swift
import ServiceManagement

// Register as login item (macOS 13+)
SMAppService.mainApp.register()

// Unregister
SMAppService.mainApp.unregister()

// Check status
SMAppService.mainApp.status
```

### File Picker Usage

```swift
// Export
let savePanel = NSSavePanel()
savePanel.allowedContentTypes = [.json]
savePanel.nameFieldStringValue = "easytier-config.json"

// Import
let openPanel = NSOpenPanel()
openPanel.allowedContentTypes = [.json]
openPanel.allowsMultipleSelection = false
```

---

## Sources

- WireGuard documentation: `wg show` CLI interface
- OpenVPN configuration profile format
- Apple Login Item API (SMAppService)
- EasyTier CLI interface (project source analysis)
- macOS Human Interface Guidelines
- Current codebase: ConfigManager, ProcessViewModel, EasyTierService

---

*Feature research for: EasyTier GUI v1.1 Enhancement Features*
*Researched: 2026-04-24*
