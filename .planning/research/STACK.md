# Stack Research

**Domain:** Swift/SwiftUI macOS Performance Optimization
**Researched:** 2025-04-24
**Confidence:** HIGH

## Performance Profiling Tools

### Primary Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Instruments - Time Profiler** | Identify CPU hotspots and main thread stalls | Startup analysis, connection blocking |
| **Instruments - Allocations** | Track memory allocations, detect leaks | Memory growth investigation |
| **Instruments - Leaks** | Automatic leak detection | Memory leak hunting |
| **Xcode Memory Graph** | Visualize object references, find retain cycles | Debugging memory issues |

### Secondary Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| **Instruments - System Trace** | System-level performance | Deep performance analysis |
| **os_signpost** | Custom performance markers | Measuring specific code paths |
| **Logger/OSLog** | Performance logging | Production diagnostics |

## Swift Concurrency Stack

### Core Components

| Component | Version | Purpose |
|-----------|---------|---------|
| **async/await** | Swift 5.5+ | Structured concurrency |
| **@MainActor** | Swift 5.5+ | Main thread isolation |
| **Task** | Swift 5.5+ | Async task management |
| **Task.sleep** | Swift 5.7+ | Cooperative cancellation |
| **AsyncStream** | Swift 5.5+ | Async sequence handling |

### Best Practices

1. **MainActor Isolation**
   - All `ObservableObject` ViewModels should be `@MainActor`
   - Services doing I/O should NOT be `@MainActor`
   - Use `await MainActor.run { }` to return to main thread

2. **Background Offloading**
   - `DispatchQueue.global(qos: .userInitiated)` for user-triggered work
   - `DispatchQueue.global(qos: .utility)` for background polling
   - `Task.detached` for CPU-bound work

3. **Continuation Pattern**
   - Wrap synchronous blocking APIs in `withCheckedThrowingContinuation`
   - Always resume continuation exactly once
   - Handle both success and error paths

## Combine Framework

### Memory Management

| Pattern | Purpose | Implementation |
|---------|---------|----------------|
| `Set<AnyCancellable>` | Store subscriptions | `var cancellables = Set<AnyCancellable>()` |
| `.store(in:)` | Track subscription lifetime | `sink { }.store(in: &cancellables)` |
| `cancellables.removeAll()` | Clean up | Call in `deinit` |

### Common Pitfalls

- Creating subscriptions in methods (not init) → accumulation
- Missing `[weak self]` in sink closures → retain cycles
- Forgetting to store AnyCancellable → immediate cancellation

## SwiftUI Performance

### Rendering Optimization

| Technique | Purpose | When to Apply |
|-----------|---------|---------------|
| `Identifiable` | Stable row identity | All ForEach items |
| `Equatable` | Prevent unnecessary rebuilds | Complex models |
| `LazyVStack` | Render only visible | Large lists (>50 items) |
| `.task {}` | View lifecycle async work | Data loading |

### State Management

| Property Wrapper | Ownership | Use Case |
|------------------|-----------|----------|
| `@StateObject` | View owns | ViewModel created by view |
| `@ObservedObject` | External owns | ViewModel passed in |
| `@EnvironmentObject` | Global | Shared state |

## Process Management

### Best Practices

1. **Never run Process on main thread**
   ```swift
   DispatchQueue.global(qos: .userInitiated).async {
       try process.run()
   }
   ```

2. **Handle termination**
   ```swift
   process.terminationHandler = { [weak self] _ in
       Task { @MainActor in
           self?.handleProcessExit()
       }
   }
   ```

3. **Clean up FileHandles**
   ```swift
   process.standardOutput?.fileHandleForReading.readabilityHandler = nil
   ```

## Timer Management

### Modern Pattern

```swift
private var peerTimer: Timer?

func startPolling() {
    peerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.fetchPeers()
        }
    }
}

func stopPolling() {
    peerTimer?.invalidate()
    peerTimer = nil
}

deinit {
    peerTimer?.invalidate()
}
```

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Alternative |
|--------------|---------|-------------|
| `DispatchQueue.main.async` in `@MainActor` | Redundant, ordering issues | Remove - already on main |
| `[unowned self]` in timers | Crash if deallocated | Use `[weak self]` |
| Index-based `ForEach` | State loss | Use `Identifiable` |
| `@Published` for all state | Excessive re-renders | Only UI-affecting state |
| Timer without invalidate | Memory leak | Always invalidate in deinit |

## Recommended Toolchain

- **Xcode 15+** with Swift 5.9
- **Instruments** for profiling
- **Memory Graph Debugger** for leaks
- **OSLog** for production diagnostics

---
*Stack research for: Swift/SwiftUI macOS Performance Optimization*
*Researched: 2025-04-24*
