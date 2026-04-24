# Coding Conventions

**Analysis Date:** 2025-04-24

## Naming Patterns

### Files
- **PascalCase** for all Swift files matching the primary type
- View files: `{Feature}View.swift` (`ConnectionView.swift`)
- Service files: `{Feature}{Role}.swift` (`EasyTierService.swift`, `ConfigManager.swift`)
- Objective-C: PascalClassName matching class (`PrivilegedExecutor.m`)

### Types
- **Structs:** PascalCase nouns (`EasyTierConfig`, `PeerInfo`)
- **Classes:** PascalCase with role suffix (`ProcessViewModel`, `NetworkRuntime`)
- **Enums:** PascalCase, values camelCase (`NetworkStatus.connected`)
- **Protocols:** PascalCase often with suffix (`Codable`, `Identifiable`)

### Variables & Properties
- **Properties:** camelCase (`networkName`, `isRunning`)
- **Published properties:** camelCase with descriptive names (`activeConfigIndex`, `downloadProgress`)
- **Private properties:** camelCase with `_` prefix for backing stores (`_configs` not used, rely on access control)
- **Constants:** camelCase within types, descriptive (`maxLogEntries`, `saveDebounceInterval`)

### Functions & Methods
- **Actions:** camelCase verbs (`connect()`, `disconnect()`, `startPeerPolling()`)
- **Queries:** camelCase starting with verb describing return (`status(for:)`, `binaryPath(for:)`)
- **Async:** No special prefix, use `async` keyword (`checkForUpdate()`)
- **Private helpers:** camelCase with descriptive names (`normalizedListenPort(for:)`)

## Code Style

### Formatting
- **Indentation:** 4 spaces (Xcode default)
- **Line length:** ~120 characters practical limit
- **Braces:** Same-line opening brace (`func foo() {`)
- **Trailing closures:** Use when final parameter is closure

### Access Control
```swift
// Public API for external use
func connect(config: EasyTierConfig) async

// Internal for module use
func syncRuntimes(with configs: [EasyTierConfig])

// Private implementation details
private func firstAvailablePort(...) -> Int
```

### Mark Comments
Use `// MARK: - ` for section organization:
```swift
// MARK: - Published Properties
// MARK: - Initialization
// MARK: - Connection Control
// MARK: - Private Methods
```

## Import Organization

**Order:**
1. Foundation (always first)
2. SwiftUI / AppKit / UIKit
3. Combine (if used)
4. Other Apple frameworks (Security, Darwin)
5. Project modules (none, flat structure)

**Example:**
```swift
import Foundation
import Combine
import SwiftUI
import Darwin
```

## Error Handling

### Error Types
Define domain-specific errors conforming to `LocalizedError`:
```swift
enum EasyTierError: LocalizedError {
    case executableNotFound(String)
    case requiresPrivileges

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "可执行文件不存在: \(path)"
        case .requiresPrivileges:
            return "当前会话尚未完成管理员授权"
        }
    }
}
```

### Patterns
- **Throw for unexpected failures** (file missing, auth failed)
- **Return optionals for expected nil** (version not detected)
- **Use @Published errorMessage** for UI display
- **Async throws** for async operations that can fail

### Async Error Handling
```swift
do {
    try await service.start(config: config)
} catch {
    errorMessage = error.localizedDescription
    status = .error
}
```

## Combine & Concurrency

### Publishers
- Store cancellables: `private var cancellables = Set<AnyCancellable>()`
- Use `.receive(on: DispatchQueue.main)` before UI updates
- Remove duplicates where appropriate: `.removeDuplicates()`

### MainActor
- ViewModels marked `@MainActor` for thread safety
- Background work dispatched explicitly:
```swift
DispatchQueue.global(qos: .userInitiated).async {
    // Heavy work
}
```
- `@MainActor` closures for UI updates from background:
```swift
Task { @MainActor in
    self.peers = newPeers
}
```

## Comments

### When to Comment
- **Explain why, not what:** `// Retry 3 times because API has transient failures`
- **Document business logic:** `// Users must verify email within 24 hours`
- **Mark sections:** `// MARK: - Connection Control`
- **Document complex workarounds:** Delay mechanisms for activation policy changes

### Avoid
- Obvious comments: `// Set status to connected`
- Redundant type info: `// String for name`

### Chinese Comments
UI-facing strings and user documentation use Chinese. Code comments primarily English with Chinese UI strings.

## SwiftUI Patterns

### State Management
```swift
// View uses EnvironmentObject for shared state
@EnvironmentObject var vm: ProcessViewModel

// Internal view state uses @State
@State private var selectedTab: AppTab = .connection

// Bindings for child views
@Binding var selectedTab: AppTab
```

### View Composition
- Extract subviews for readability (`SidebarView`, `DetailView`)
- Use `Preview` macros for canvas preview
- Frame constraints in `WindowGroup` configuration

## Function Design

### Size
- Keep under 50 lines where practical
- Extract helpers for complex logic (port normalization, peer fetching)

### Parameters
- Max 3-4 parameters
- Use structs for complex configuration
- Trailing closure syntax for completion handlers

### Async/Await
Prefer async/await over completion handlers:
```swift
// Preferred
func checkForUpdate() async {
    let release = try await service.fetchLatestRelease()
}

// Avoid
func checkForUpdate(completion: (Result<Release, Error>) -> Void)
```

## Singleton Pattern

Use sparingly for true system-wide resources:
```swift
static let shared = BinaryManager()
private init() { }
```

Examples in codebase:
- `BinaryManager.shared`
- `MenuBarManager.shared`
- `AppDelegate.shared` (weak optional)

## Localization

Current approach: Hardcoded Chinese strings in UI

Locations with Chinese:
- User alert messages (`showAuthorizationError`)
- UI labels (`Label(tab.label, systemImage: tab.icon)`)
- Error messages (in `LocalizedError` implementations)

---

*Convention analysis: 2025-04-24*
*Update when patterns change*
