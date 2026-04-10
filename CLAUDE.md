# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EasyTier GUI is a macOS SwiftUI application that provides a graphical interface for EasyTier, a P2P mesh VPN tool. The app manages network configurations, runs easytier-core processes, and displays connection status and peer information.

**Key Requirements:**
- macOS 14.0+ (uses modern SwiftUI and AppKit APIs)
- Xcode 15.0+ for compilation
- Requires root/sudo privileges to create TUN network devices
- External `easytier-core` and `easytier-cli` binaries (downloaded separately from EasyTier releases)

## Build Commands

```bash
# Build the application (Release configuration)
./build.sh

# Build with specific configuration
./build.sh Debug

# Manual build via xcodebuild
xcodebuild build \
    -project EasyTierGUI.xcodeproj \
    -scheme EasyTierGUI \
    -configuration Release \
    -derivedDataPath .build/DerivedData

# Run with root privileges (required for TUN device creation)
sudo .build/DerivedData/Build/Products/Release/EasyTierGUI.app/Contents/MacOS/EasyTierGUI

# Or use the launcher script
./launch-easytier-gui.sh
```

## Architecture

### MVVM Pattern
- **Views/**: SwiftUI views (`ContentView`, `ConnectionView`, `PeersView`, `LogView`, `SettingsView`)
- **ViewModels**: `ProcessViewModel` (main app state), `NetworkRuntime` (per-network runtime state)
- **Models/**: `EasyTierConfig`, `TunConfig`, `PeerInfo`, `LogEntry`, `NetworkStatus`

### Core Services

**ProcessViewModel** (`Services/ProcessViewModel.swift`):
- Central coordinator managing multiple network configurations and their runtimes
- Routes connect/disconnect operations to appropriate `NetworkRuntime` instances
- Syncs with `ConfigManager` for configuration persistence

**EasyTierService** (`Services/EasyTierService.swift`):
- Manages `easytier-core` process lifecycle (start, stop, output capture)
- Handles privileged execution when app runs without root (uses Authorization Services)
- Parses log output and fetches peer info via `easytier-cli`

**ConfigManager** (`Services/ConfigManager.swift`):
- Persists network configurations to `~/Library/Application Support/EasyTierGUI/`
- Handles config import/export, port normalization to avoid conflicts

**MenuBarManager** (`Services/MenuBarManager.swift`):
- System menu bar status item showing connection state
- Allows showing/hiding main window, displays per-network status

### Privilege Handling

The app checks for root privileges at launch via `getuid()`. If not running as root:
1. Prompts user for authorization via macOS Authorization Services
2. Uses `PrivilegedSessionManager`/`PrivilegedExecutor` to run commands with elevated privileges
3. Processes spawn in background with output redirected to temp log file

### Configuration Storage

- Configs stored as JSON in `~/Library/Application Support/EasyTierGUI/configs.json`
- Active config index stored in `active_index.json`
- User preferences (executable path, dock/menu bar visibility) in `UserDefaults`

## External Dependencies

- **easytier-core**: Main VPN daemon (required in PATH or specified in settings)
- **easytier-cli**: CLI tool for peer listing (optional, used for peer discovery)

Binary search paths: configured path → `/usr/local/bin` → `/opt/homebrew/bin`

## Localization

UI is currently in Chinese (简体中文). Status messages and error dialogs use Chinese text.
