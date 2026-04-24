# Technology Stack

**Analysis Date:** 2025-04-24

## Languages

**Primary:**
- **Swift 5.9** - All application logic (`EasyTierGUI/**/*.swift`)
- **SwiftUI** - UI layer and declarative views
- **Objective-C** - Privilege escalation bridging (`PrivilegedExecutor.m`)

**Configuration:**
- 
Property List (plist)** - App metadata and entitlements (`Info.plist`)
- **Shell/Bash** - Build automation scripts (`build.sh`, `create-dmg.sh`)

## Runtime

**Environment:**
- macOS 14.0+ (Sonoma) - Minimum deployment target
- Universal Binary support (arm64 Apple Silicon + x86_64 Intel)

**Frameworks:**
- **SwiftUI** - Primary UI framework
- **Combine** - Reactive programming for state management (`ProcessViewModel.swift`, `ConfigManager.swift`)
- **AppKit** (via NSViewRepresentable, NSWindow) - Window management and system integration
- **Foundation** - Core system services ( Process, FileManager, UserDefaults)

**Security & System:**
- **Security.framework** - Authorization Services for privilege escalation (`PrivilegedExecutor.m`)
- **Darwin** - Low-level Unix APIs for process management

## Dependencies

**External Binaries (bundled):**
- **easytier-core** - Main P2P VPN daemon (~v2.4.5+)
- **easytier-cli** - CLI tool for peer information queries

**No external Swift Package Manager dependencies** - The project uses only Apple frameworks to minimize binary size and dependency complexity.

## Key Components

**View Layer:**
- `ContentView.swift` - Main window with `NavigationSplitView`
- `ConnectionView.swift` - Network configuration form
- `PeersView.swift` - Connected nodes display
- `LogView.swift` - Real-time log viewer
- `SettingsView.swift` - App preferences and core updates

**Service Layer:**
- `EasyTierService.swift` - Process lifecycle management
- `ProcessViewModel.swift` - Multi-network runtime coordination
- `ConfigManager.swift` - Configuration persistence
- `BinaryManager.swift` - Built-in core version management
- `MenuBarManager.swift` - System menu bar integration

**System Integration:**
- `PrivilegedExecutor.m/.h` - Objective-C bridging for Authorization Services
- `EasyTierGUI-Bridging-Header.h` - Swift/ObjC interop

## Build System

**Xcode Project:**
- `EasyTierGUI.xcodeproj` - Standard Xcode project
- Target: `EasyTierGUI.app` macOS app bundle
- Architecture: Universal Binary (ARCHS = arm64, x86_64)

**Build Scripts:**
- `build.sh` - Full build with dependency download
- `create-dmg.sh` - DMG installer creation
- `launch-easytier-gui.sh` - Root privilege launcher

**Build Features:**
- Automatic download of EasyTier binaries from GitHub releases
- Universal Binary creation via `lipo`
- Binary embedding in app bundle Resources
- DerivedData in local `.build/DerivedData` (ignored by git)

## Platform Requirements

**Development:**
- macOS 14.0+ (Sonoma)
- Xcode 15+
- Swift 5.9+

**Production:**
- macOS 14.0+ minimum
- Requires root privileges for TUN device creation
- Code signing for proper Authorization Services behavior

---

*Stack analysis: 2025-04-24*
*Update after major dependency changes*
