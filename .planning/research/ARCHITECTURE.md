# Architecture Research

**Domain:** SwiftUI macOS Desktop GUI Application (Native)
**Researched:** 2025-04-24
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          View Layer (SwiftUI)                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │ContentView  │  │ConnectionView│ │  PeersView  │  │ LogView   │  │
│  │ (Shell)     │  │ (Form UI)   │  │ (Table)     │  │ (Stream)  │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │
│         │                │                │                │        │
│         └────────────────┴────────────────┴────────────────┘        │
│                                    │                                 │
│                          @EnvironmentObject                          │
├─────────────────────────────────────────────────────────────────────┤
│                       ViewModel Layer (@MainActor)                   │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────┐  ┌───────────────────────────┐   │
│  │    ProcessViewModel           │  │    NetworkRuntime         │   │
│  │  (Main Coordinator)           │  │  (Per-Network State)      │   │
│  │  - Config coordination        │  │  - Connection status      │   │
│  │  - Multi-runtime management   │  │  - Peer polling           │   │
│  │  - Status aggregation         │  │  - Error handling         │   │
│  └───────────────┬───────────────┘  └─────────────┬─────────────┘   │
│                  │                                 │                  │
├──────────────────┴─────────────────────────────────┴─────────────────┤
│                           Service Layer                               │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │EasyTierSvc  │  │ConfigManager│  │BinaryManager│  │MenuBarMgr  │  │
│  │(Process)    │  │(Persistence)│  │(Updates)    │  │(System UI) │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│                           System Layer                                │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │            PrivilegedExecutor (Objective-C Bridge)            │  │
│  │            Authorization Services for root operations          │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| View Layer | UI rendering, user interaction | SwiftUI views with `@EnvironmentObject` binding |
| ProcessViewModel | Main coordinator, multi-network management | `@MainActor class`, `ObservableObject` |
| NetworkRuntime | Per-network runtime state and lifecycle | `@MainActor class`, peer polling timer |
| EasyTierService | Process lifecycle, I/O parsing | Non-actor class, DispatchQueue for I/O |
| ConfigManager | Configuration persistence | `ObservableObject`, debounced saves |
| BinaryManager | Core binary updates, GitHub API | Singleton, async/await networking |
| MenuBarManager | System status bar integration | NSStatusBar, AppKit bridge |
| PrivilegedExecutor | Root privilege escalation | Objective-C, Authorization Services |

## Recommended Project Structure

```
EasyTierGUI/
├── EasyTierGUIApp.swift      # App entry point, AppDelegate
├── Models/
│   ├── Models.swift          # EasyTierConfig, PeerInfo, LogEntry
│   └── BinaryVersion.swift   # Update metadata
├── Services/
│   ├── ProcessViewModel.swift    # Main ViewModel + NetworkRuntime
│   ├── EasyTierService.swift     # Process management
│   ├── ConfigManager.swift       # Persistence layer
│   ├── BinaryManager.swift       # Core updates
│   ├── MenuBarManager.swift      # Status bar
│   ├── GitHubReleaseService.swift # API client
│   └── PrivilegedExecutor.m      # Objective-C bridge
└── Views/
    ├── ContentView.swift         # Main shell + sidebar
    ├── ConnectionView.swift      # Config form
    ├── PeersView.swift           # Node table
    ├── LogView.swift             # Log stream
    └── SettingsView.swift        # Preferences
```

### Structure Rationale

- **Models/**: Pure data structures, `Codable` for persistence, no dependencies
- **Services/**: Business logic, external resource management, ObservableObject for reactivity
- **Views/**: SwiftUI declarations only, business logic delegated to ViewModels

## Architectural Patterns

### Pattern 1: MainActor Isolation

**What:** All UI-bound ViewModels are isolated to the main actor, ensuring thread-safe UI updates.

**When to use:** All `ObservableObject` classes that publish state consumed by SwiftUI views.

**Trade-offs:**
- **Pro:** Eliminates race conditions on UI state
- **Pro:** Automatic main thread dispatch for `@Published` updates
- **Con:** Must explicitly use `Task` for background work
- **Con:** Can cause UI blocking if heavy work stays on MainActor

**Example:**
```swift
@MainActor
final class NetworkRuntime: ObservableObject {
    @Published var status: NetworkStatus = .disconnected
    @Published var peers: [PeerInfo] = []

    func connect(config: EasyTierConfig) async {
        status = .connecting  // Safe: on MainActor

        // Offload blocking work
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Privileged execution on background thread
                do {
                    try self.startPrivileged(config: config)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
```

### Pattern 2: Background Queue Offloading

**What:** Heavy I/O, process management, and networking execute on dedicated background queues.

**When to use:**
- Process execution (Process.run())
- File I/O (log reading, config persistence)
- Network requests (GitHub API)
- Peer fetching via CLI

**Trade-offs:**
- **Pro:** Main thread never blocked
- **Pro:** Responsive UI during heavy operations
- **Con:** Must manually dispatch results back to main thread
- **Con:** More complex error handling across threads

**Example:**
```swift
class EasyTierService: ObservableObject {
    private let peerFetchQueue = DispatchQueue(label: "EasyTierGUI.PeerFetch", qos: .utility)

    func fetchPeers(rpcPortalPort: Int, completion: @escaping ([PeerInfo]) -> Void) {
        peerFetchQueue.async {
            // Background: run CLI process
            let task = Process()
            // ... process setup ...
            try? task.run()

            // Return to main thread
            DispatchQueue.main.async {
                completion(peers)
            }
        }
    }
}
```

### Pattern 3: Combine Subscription Lifecycle Management

**What:** Store `AnyCancellable` in `Set<AnyCancellable>` on the owning object, clear in `deinit`.

**When to use:** All `ObservableObject` classes that subscribe to publishers.

**Trade-offs:**
- **Pro:** Automatic cleanup when object deallocates
- **Pro:** Prevents memory leaks from orphaned subscriptions
- **Con:** Must remember to store each subscription

**Example:**
```swift
@MainActor
final class NetworkRuntime: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    init() {
        service.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                self?.status = isRunning ? .connected : .disconnected
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
    }
}
```

### Pattern 4: Timer-Based Polling with Weak Self

**What:** Periodic background tasks use `Timer` with `[weak self]` captures to prevent retain cycles.

**When to use:** Peer polling, log monitoring, periodic update checks.

**Trade-offs:**
- **Pro:** Timer invalidated on deinit
- **Pro:** Weak reference prevents retain cycle
- **Con:** Timer still runs if object leaked (safety net)

**Example:**
```swift
private func startPeerPolling() {
    peerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.fetchPeers()
        }
    }
}

private func stopPeerPolling() {
    peerTimer?.invalidate()
    peerTimer = nil
}

deinit {
    peerTimer?.invalidate()
}
```

### Pattern 5: Async/Await for Long-Running Operations

**What:** Use Swift's structured concurrency for sequential async operations with proper cancellation.

**When to use:** Connection/disconnection sequences, update downloads.

**Trade-offs:**
- **Pro:** Cooperative cancellation via `Task.isCancelled`
- **Pro:** Cleaner code than completion handlers
- **Pro:** Automatic error propagation
- **Con:** Requires iOS 15+/macOS 12+

**Example:**
```swift
func disconnectAll() async {
    await withTaskGroup(of: Void.self) { group in
        for runtime in runtimes.values {
            group.addTask {
                await runtime.disconnect()
            }
        }
    }
    refreshOverallStatus()
}
```

## Data Flow

### Connection Request Flow

```
[User Click Connect]
        │
        ▼
ConnectionView.swift (SwiftUI Button)
        │
        ▼ Task { @MainActor in
ProcessViewModel.connect(configID:)
        │
        ├─► Validate config (MainActor - fast)
        │
        ├─► Check port conflicts (MainActor - fast)
        │
        └─► NetworkRuntime.connect(config:)
                │
                ▼ status = .connecting
                │
                ▼ withCheckedThrowingContinuation
                ┌───────────────────────────────────┐
                │ DispatchQueue.global(.userInitiated)│
                │     └─► PrivilegedExecutor.run()   │
                │          (Authorization Services)   │
                │          [Background Thread]        │
                └───────────────────────────────────┘
                                │
                                ▼ continuation.resume()
                │
                ▼ status = .connected
                │
                ▼ startPeerPolling() (Timer on RunLoop)
```

### State Update Flow

```
[Process stdout/stderr]
        │
        ▼
FileHandle.readabilityHandler (Background Queue)
        │
        ▼ DispatchQueue.main.async
parseLogEntries()
        │
        ▼ @Published logEntries.append()
        │
        ▼ SwiftUI (implicitly on MainActor)
LogView.body renders
```

### Key Data Flows

1. **Configuration Persistence:** User edit → `@Published` update → Debounced save (0.5s) → Background queue write → Atomic JSON file
2. **Peer Polling:** Timer fires → `peerFetchQueue` runs CLI → Parse JSON → `DispatchQueue.main` → Update `@Published peers`
3. **Status Aggregation:** Each `NetworkRuntime` publishes status → `ProcessViewModel` aggregates → `MenuBarManager` updates status bar

## Swift 5.9 Concurrency Model

### Main Thread Protection Strategies

| Strategy | Implementation | Use Case |
|----------|---------------|----------|
| `@MainActor` on ViewModel | Class-level isolation | All ObservableObject ViewModels |
| `Task { @MainActor in }` | Explicit main dispatch | Callbacks from background |
| `DispatchQueue.main.async` | Classic GCD | Legacy code, non-async contexts |
| `receive(on: DispatchQueue.main)` | Combine operator | Publisher subscriptions |

### Thread Safety Rules

1. **All `@Published` property updates must occur on MainActor**
   - ViewModels marked `@MainActor` guarantee this
   - Services without `@MainActor` must dispatch manually

2. **Background work uses dedicated queues**
   - I/O operations: `DispatchQueue(label: "...", qos: .utility)`
   - Network operations: `URLSession.shared.data(from:)` (async)
   - Process management: `DispatchQueue.global(qos: .userInitiated)`

3. **Never block the main thread**
   - Process.run() → Always on background queue
   - File I/O → Always on background queue
   - Authorization prompts → Already handled by OS asynchronously

### Build Order Implications for Optimizations

When implementing performance optimizations, follow this order:

1. **Phase 1: Identify blockers**
   - Profile with Instruments (Time Profiler)
   - Look for main thread stalls during:
     - App launch
     - Connection/disconnection
     - Peer polling

2. **Phase 2: Offload blocking work**
   - Wrap synchronous privileged calls in `withCheckedThrowingContinuation`
   - Move file I/O to background queues
   - Use `Task.detached` for CPU-bound work

3. **Phase 3: Memory audit**
   - Verify all `AnyCancellable` stored in Sets
   - Ensure Timer invalidation in `deinit`
   - Check for retain cycles with `[weak self]`

4. **Phase 4: UI responsiveness**
   - Add loading states for async operations
   - Implement progress indicators
   - Add cancellation support

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-10 network configs | Current architecture sufficient |
| 10-50 network configs | Consider lazy runtime creation, reduce polling frequency |
| 50+ network configs | Consider pooling, on-demand peer fetching, background aggregation |

### Scaling Priorities

1. **First bottleneck:** Peer polling overhead with many networks
   - **Fix:** Reduce polling frequency, or poll only active network
2. **Second bottleneck:** Memory from log buffers
   - **Fix:** Reduce `maxLogEntries`, implement disk-backed buffer

## Anti-Patterns

### Anti-Pattern 1: Synchronous Main Thread Blocking

**What people do:** Call blocking APIs directly in ViewModel methods without offloading

```swift
// WRONG: Blocks main thread
func connect() {
    try PrivilegedExecutor.runCommand(...) // Shows auth dialog, blocks UI
}
```

**Why it's wrong:** Authorization Services and process execution can take seconds, causing the spinning beach ball.

**Do this instead:**
```swift
func connect() async throws {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try PrivilegedExecutor.runCommand(...)
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Anti-Pattern 2: Unowned Self in Closures

**What people do:** Use `[unowned self]` to avoid retain cycles

```swift
// WRONG: Can crash if self deallocates
Timer.scheduledTimer { [unowned self] _ in
    self.fetchPeers()
}
```

**Why it's wrong:** If the timer fires after `self` deallocates, the app crashes.

**Do this instead:**
```swift
Timer.scheduledTimer { [weak self] _ in
    guard let self else { return }
    Task { @MainActor in
        self.fetchPeers()
    }
}
```

### Anti-Pattern 3: MainActor-isolated Services

**What people do:** Mark all ObservableObjects as `@MainActor`

```swift
// WRONG: Blocks main thread for I/O
@MainActor
class EasyTierService: ObservableObject {
    func fetchPeers() {
        // Process.run() on main thread
    }
}
```

**Why it's wrong:** The service's I/O operations block the main thread.

**Do this instead:**
```swift
// Service is NOT @MainActor - can do background work
class EasyTierService: ObservableObject {
    @Published var isRunning = false  // Publisher is thread-safe

    func fetchPeers(completion: @escaping ([PeerInfo]) -> Void) {
        peerFetchQueue.async {
            // Background work
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

// ViewModel IS @MainActor - coordinates UI state
@MainActor
class NetworkRuntime: ObservableObject {
    let service = EasyTierService()  // Service can do background work
}
```

### Anti-Pattern 4: Timer Without Invalidation

**What people do:** Create timers without storing or invalidating them

```swift
// WRONG: Timer runs forever, self never deallocates
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
    self.fetchPeers()
}
```

**Why it's wrong:** Timer retains its target, creating a retain cycle.

**Do this instead:**
```swift
private var peerTimer: Timer?

private func startPeerPolling() {
    peerTimer = Timer.scheduledTimer(...) { [weak self] _ in
        // ...
    }
}

deinit {
    peerTimer?.invalidate()
    peerTimer = nil
}
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| easytier-core (subprocess) | Process + Pipe | Background queue, async output reading |
| easytier-cli (subprocess) | Process + Pipe | Background queue, timeout handling |
| GitHub API | URLSession async | Native async/await, no background queue needed |
| Authorization Services | Objective-C bridge | OS handles async dialog, return to caller |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | `@Published` bindings | SwiftUI auto-updates on MainActor |
| ViewModel ↔ Service | Method calls, closures | Services may be non-MainActor |
| Service ↔ System | GCD, async/await | Background queues for blocking ops |

## Key Findings for Current Codebase

### What's Working Well

1. **MainActor isolation on ViewModels** - `ProcessViewModel` and `NetworkRuntime` correctly isolated
2. **Background queue offloading** - `peerFetchQueue` for CLI calls
3. **Weak self in timers** - Peer polling uses `[weak self]`
4. **AnyCancellable storage** - Sets used correctly
5. **Continuation pattern** - Privileged execution wrapped in `withCheckedThrowingContinuation`

### Areas for Optimization

1. **Potential main thread blocking:**
   - `startPrivileged(config:)` called from continuation, but `Thread.sleep` inside
   - `cleanupOrphanedProcesses()` may block during app launch
   - Config file writes should be on background queue (verify `debounced save` implementation)

2. **Memory considerations:**
   - `NetworkRuntime` instances accumulate in `runtimes` dictionary
   - Log buffer `maxLogEntries = 100` per service (could grow with many networks)
   - Timer cleanup relies on `deinit` - verify all paths trigger deallocation

3. **Concurrency improvements:**
   - Replace `Timer` with `Task.sleep` for cooperative cancellation
   - Use `AsyncStream` for log reading instead of closure callbacks
   - Consider `actor` for `EasyTierService` state isolation

## Sources

- [Swift Concurrency - The Complete Guide](https://www.hackingwithswift.com/swift/5.5/actors)
- [MainActor usage in SwiftUI - SwiftLee](https://www.avanderlee.com/concurrency/mainactor-dispatchqueue-main/)
- [Apple Developer Documentation - MainActor](https://developer.apple.com/documentation/swift/mainactor)
- [Combine Framework - Memory Management](https://developer.apple.com/documentation/combine)

---
*Architecture research for: SwiftUI macOS Desktop GUI Application*
*Researched: 2025-04-24*
