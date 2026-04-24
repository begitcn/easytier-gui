# Structure

**Analysis Date:** 2025-04-24

## Directory Layout

```
easytier-gui/
├── EasyTierGUI/                    # Main source directory
│   ├── EasyTierGUIApp.swift        # App entry point, AppDelegate
│   ├── EasyTierGUI-Bridging-Header.h  # Swift/ObjC interop
│   ├── Info.plist                  # App metadata, entitlements
│   ├── logo.png                    # App icon asset
│   │
│   ├── Views/                      # SwiftUI views
│   │   ├── ContentView.swift       # Main window with sidebar
│   │   ├── ConnectionView.swift    # Network config form
│   │   ├── PeersView.swift         # Connected nodes display
│   │   ├── LogView.swift           # Log stream viewer
│   │   ├── SettingsView.swift      # Preferences & updates
│   │   └── Components/             # Reusable UI components
│   │       └── UpdateBanner.swift  # Update notification banner
│   │
│   ├── Services/                   # Business logic & system integration
│   │   ├── ProcessViewModel.swift  # Main ViewModel, network coordination
│   │   ├── EasyTierService.swift   # easytier-core process management
│   │   ├── ConfigManager.swift     # Configuration persistence
│   │   ├── BinaryManager.swift     # Core version management
│   │   ├── MenuBarManager.swift    # Menu bar integration
│   │   ├── GitHubReleaseService.swift  # GitHub API client
│   │   ├── PrivilegedExecutor.h    # ObjC interface for privilege escalation
│   │   └── PrivilegedExecutor.m    # Authorization Services implementation
│   │
│   ├── Models/                     # Data structures
│   │   ├── Models.swift            # Core types (config, peer, log, status)
│   │   └── BinaryVersion.swift     # Version metadata & comparison
│   │
│   ├── Resources/                  # Bundled resources
│   │   └── easytier/               # Embedded EasyTier binaries
│   │       ├── easytier-core       # VPN daemon (auto-downloaded on build)
│   │       └── easytier-cli        # CLI tool for queries
│   │
│   └── Assets.xcassets/            # Xcode asset catalog
│       ├── AppIcon.appiconset/     # App icons (16px - 1024px)
│       ├── AccentColor.colorset/   # Theme accent color
│       └── MenuBarIcon.imageset/   # Menu bar icon
│
├── EasyTierGUI.xcodeproj/          # Xcode project
│   └── project.pbxproj             # Project configuration
│
├── .build/                         # Build outputs (gitignored)
│   └── DerivedData/                # Xcode build artifacts
│
├── .claude/                        # Claude Code configuration
│   └── skills/                     # Project-specific skills
│
├── build.sh                        # Build script with binary download
├── create-dmg.sh                   # DMG installer creation
├── launch-easytier-gui.sh          # Sudo launcher helper
├── generate-icons.sh               # Icon generation utility
├── README.md                       # Project documentation
├── LICENSE                         # License file
└── logo.png                        # Source logo image
```

## Key Locations

### Source Files

| Category | Location | Pattern |
|----------|----------|---------|
| Views | `EasyTierGUI/Views/*.swift` | `{Feature}View.swift` |
| Services | `EasyTierGUI/Services/*.swift` | `{Feature}{Manager/Service/ViewModel}.swift` |
| Models | `EasyTierGUI/Models/*.swift` | `{Type}.swift` or `Models.swift` |
| Resources | `EasyTierGUI/Resources/` | Static assets, binaries |

### Configuration

| Type | Location | Purpose |
|------|----------|---------|
| App Config | `EasyTierGUI/Info.plist` | Bundle ID, entitlements, version |
| Build Settings | `EasyTierGUI.xcodeproj/` | Target configs, build phases |
| Bridging | `EasyTierGUI/EasyTierGUI-Bridging-Header.h` | Swift/ObjC imports |
| Scripts | `build.sh`, `create-dmg.sh` | Automation |

### Runtime Data

| Type | Location | Purpose |
|------|----------|---------|
| User Configs | `~/Library/Application Support/EasyTierGUI/` | Persisted network configs |
| User Binaries | `~/Library/Application Support/EasyTierGUI/bin/` | Updated core versions |
| App Bundled | `EasyTierGUI.app/Contents/Resources/easytier/` | Shipped core binaries |

## Naming Conventions

### Files

- **Views:** PascalCase + `View` suffix (`ConnectionView.swift`)
- **Services:** PascalCase + role suffix (`EasyTierService.swift`, `ConfigManager.swift`)
- **Models:** PascalCase noun (`Models.swift`, `BinaryVersion.swift`)
- **Assets:** lowercase with hyphens (`menu-bar-icon.pdf`)

### Swift Types

- **Views:** Struct conforming to `View` (`ConnectionView`)
- **ViewModels:** Class with `ViewModel` suffix, `@MainActor` (`ProcessViewModel`)
- **Services:** Class with `Service` or `Manager` suffix, often singleton (`ConfigManager`)
- **Models:** Structs, Codable (`EasyTierConfig`, `PeerInfo`)
- **Enums:** PascalCase, associated values for state (`NetworkStatus`, `UpdateState`)

### Objective-C

- **Files:** PascalCase matching class name (`PrivilegedExecutor.m`)
- **Classes:** PascalCase prefix (`PrivilegedExecutor`)
- **Methods:** camelCase with colons (`+ (BOOL)ensureAuthorized:`)

## Module Boundaries

### Views
No direct service access - always through `ProcessViewModel`

```swift
// Correct
@EnvironmentObject var vm: ProcessViewModel
vm.connect()

// Incorrect - View shouldn't access directly
ConfigManager().addConfig(config)
```

### Services
Services communicate via Combine publishers or direct calls

```swift
// ViewModel observes service
service.$isRunning
    .receive(on: DispatchQueue.main)
    .sink { ... }

// Direct service calls
await service.start(config: config)
```

### Models
Pure data, no business logic. Codable for persistence.

```swift
struct EasyTierConfig: Codable, Identifiable, Equatable {
    // Properties only, no methods except computed properties
}
```

## Build Artifacts

### Development Builds
Location: `.build/DerivedData/Build/Products/`

### Release Builds
Location: `.build/DerivedData/Build/Products/Release/`

### DMG
Location: Project root: `EasyTierGUI.dmg`

---

*Structure documented: 2025-04-24*
*Update when file organization changes*
