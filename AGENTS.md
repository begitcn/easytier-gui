# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

EasyTier GUI is a native macOS application providing a graphical interface for [EasyTier](https://github.com/EasyTier/EasyTier), a P2P VPN networking tool. Built with SwiftUI and AppKit, supporting both Intel and Apple Silicon.

## Build Commands

```bash
# Build the application (Universal Binary)
./build.sh [Release|Debug]

# Build and create DMG installer
./build.sh && ./create-dmg.sh

# Run with root privileges (required for TUN device)
./launch-easytier-gui.sh
# Or directly:
sudo .build/DerivedData/Build/Products/Release/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
```

## Project Structure

```
EasyTierGUI/
├── EasyTierGUIApp.swift    # App entry point, AppDelegate, window management
├── Models/
│   └── Models.swift        # EasyTierConfig, PeerInfo, NetworkStatus, LogEntry
├── Services/
│   ├── EasyTierService.swift     # Process management, privileged execution
│   ├── ProcessViewModel.swift    # Main ViewModel, coordinates network runtimes
│   ├── ConfigManager.swift       # Configuration persistence
│   └── MenuBarManager.swift      # System menu bar integration
└── Views/
    ├── ContentView.swift         # Main layout with sidebar navigation
    ├── ConnectionView.swift      # Network configuration and connection UI
    ├── PeersView.swift           # Connected nodes display
    ├── LogView.swift             # Real-time log viewer
    └── SettingsView.swift        # App settings and EasyTier path config
```

## Architecture

### MVVM Pattern

- **Models**: Data structures for network configuration and runtime state
- **ViewModels**: `ProcessViewModel` manages multiple network runtimes, each with its own `EasyTierService`
- **Views**: SwiftUI views bound to `ProcessViewModel` via `@EnvironmentObject`

### Key Components

1. **ProcessViewModel**: Central coordinator managing multiple network configurations. Each network config gets its own `NetworkRuntime` instance with an `EasyTierService`.

2. **EasyTierService**: Manages the `easytier-core` subprocess lifecycle:
   - Detects and validates `easytier-core` executable
   - Handles privileged execution via `PrivilegedExecutor` (Objective-C bridging)
   - Parses stdout/stderr for log entries
   - Polls for peer information via `easytier-cli`

3. **ConfigManager**: Persists network configurations to `~/Library/Application Support/EasyTierGUI/` as JSON files. Automatically assigns non-conflicting ports.

4. **MenuBarManager**: System menu bar icon showing connection status, allowing quick access and window restoration.

### Privilege Handling

The app requires root privileges to create TUN network devices. Two execution modes:

1. **Direct sudo launch**: `sudo EasyTierGUI.app/Contents/MacOS/EasyTierGUI`
2. **Authorization Services**: Uses `PrivilegedExecutor` (Objective-C) to run `easytier-core` with elevated privileges when the app itself is not running as root.

## External Dependencies

- **easytier-core**: Main VPN executable, must be in PATH or configured in Settings
- **easytier-cli**: CLI tool for peer discovery (optional, used for node listing)

Download from [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases).

## Development Notes

- Minimum macOS version: 14.0 (Sonoma)
- Swift 5.9, SwiftUI + AppKit hybrid
- The app uses `@StateObject` for ViewModels and passes them via `@EnvironmentObject`
- Network configurations are identified by UUID; ports are auto-assigned to avoid conflicts
- The app supports running multiple network configurations simultaneously
