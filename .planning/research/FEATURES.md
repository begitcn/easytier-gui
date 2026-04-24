# Feature Research

**Domain:** Swift/SwiftUI macOS Performance Optimization
**Researched:** 2025-04-24
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Performance features users assume exist. Missing these = app feels broken or amateur.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Main thread responsiveness | Mac users expect UI never freezes; spinning beach ball = broken | MEDIUM | `@MainActor`, async/await, background queues for I/O |
| Launch time < 1s | Instant launch is macOS norm; delay suggests poor quality | MEDIUM | Defer non-critical work, lazy initialization |
| Memory stability | Apps should run indefinitely without memory growth | MEDIUM | Proper subscription cleanup, bounded buffers, weak references |
| Smooth animations | 60fps scroll/transitions; jank = poor polish | LOW | Avoid main thread blocking during animations |
| Proper loading states | Every action needs immediate visual acknowledgment | LOW | Progress indicators, disabled states during operations |
| Error feedback | Operations fail gracefully with user-friendly messages | LOW | Alerts, toasts, inline error messages |
| Clean shutdown | No orphan processes, proper resource cleanup | MEDIUM | Process termination, timer invalidation, subscription disposal |

### Differentiators (Competitive Advantage)

Performance features that distinguish excellent macOS apps from adequate ones.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Speculative prefetching | Anticipate user actions, pre-load data for instant response | HIGH | Pre-connect networks, cache peer info |
| Incremental UI updates | Large data changes without full view rebuilds | MEDIUM | `Identifiable` conformance, diffable data sources |
| Background task coalescing | Batch periodic work to minimize CPU wakeups | MEDIUM | Timer consolidation, debouncing |
| Memory pressure handling | Respond to system memory warnings, purge caches | MEDIUM | `NSCache`, `autoreleasepool`, cache eviction policies |
| Lazy view loading | Only build views when displayed | LOW | `LazyVStack`, conditional view creation |
| Optimistic UI updates | Show expected result immediately, reconcile on completion | HIGH | Connect appears instant, revert if fails |
| Smooth state transitions | Animated state changes, no jarring jumps | MEDIUM | `withAnimation`, transition modifiers |
| Energy efficiency | Minimal CPU/battery usage when idle | HIGH | Event-driven vs polling, efficient timers |

### Anti-Features (Commonly Requested, Often Problematic)

Performance approaches that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Eager loading everywhere | "Everything should be instant" | High memory footprint, slow launch | Lazy loading + strategic prefetching |
| Real-time updates on everything | "Always show latest data" | Excessive CPU/battery, unnecessary redraws | Polling intervals, on-demand refresh |
| Large log buffers | "Never lose log history" | Memory grows unbounded | Bounded circular buffer + export to file |
| Global singleton state | "Easy access from anywhere" | Hard to test, lifecycle issues | Dependency injection, scoped state |
| Main thread assertions everywhere | "Be extra safe" | Noise hides real issues, performance cost | Strategic use at boundaries |
| Premature optimization | "Make everything fast" | Complexity without proven benefit | Profile first, optimize bottlenecks |

## Feature Dependencies

```
Main Thread Responsiveness
    └──requires──> Async/Await or GCD Background Queues
                       └──requires──> Thread-safe state access

Memory Stability
    └──requires──> Subscription Cleanup (AnyCancellable)
    └──requires──> Bounded Data Structures
    └──requires──> Weak References in Closures

Incremental UI Updates
    └──requires──> Identifiable Models
    └──requires──> Equatable for diffing

Background Task Coalescing
    └──enhances──> Energy Efficiency
    └──enhances──> Main Thread Responsiveness

Optimistic UI Updates
    └──requires──> Error Handling with Rollback
    └──conflicts──> Simple synchronous operations (over-engineering)

Speculative Prefetching
    └──enhances──> Launch Time
    └──conflicts──> Memory Efficiency (trade-off)
```

### Dependency Notes

- **Main Thread Responsiveness requires Async/Await:** Blocking I/O must move off main thread; Swift concurrency or GCD provides mechanism
- **Memory Stability requires Subscription Cleanup:** Combine subscriptions hold references; improper cleanup = leaks
- **Incremental UI Updates requires Identifiable:** SwiftUI needs stable IDs to diff and update individual rows vs rebuilding entire lists
- **Background Task Coalescing enhances Energy Efficiency:** Fewer CPU wakeups = less battery drain
- **Optimistic UI Updates conflicts with Simple synchronous operations:** For trivial operations, optimistic update adds complexity without benefit
- **Speculative Prefetching conflicts with Memory Efficiency:** Pre-loading trades memory for speed; must balance

## MVP Definition

### Launch With (v1)

Minimum viable performance — what's needed for acceptable user experience.

- [x] Main thread never blocks — All I/O, process spawning, network calls on background queues
- [x] Bounded log buffer — Circular buffer with max entries (already: `maxLogEntries = 100`)
- [x] Loading states on all actions — Button disabled + spinner during connect/disconnect
- [x] Proper error messages — User-friendly text, not technical stack traces
- [x] Subscription cleanup — `AnyCancellable` stored in set, cleared on deinit
- [x] Timer invalidation — Peer polling timers properly stopped when network disconnects

### Add After Validation (v1.x)

Performance improvements to add once core stability is verified.

- [ ] Startup optimization — Defer non-critical initialization, measure launch time
- [ ] Debounced config saves — Already partially implemented, ensure consistent
- [ ] Animation polish — Smooth transitions for state changes
- [ ] Memory warning handling — Respond to `applicationDidReceiveMemoryWarning`

### Future Consideration (v2+)

Advanced optimizations after product-market fit.

- [ ] Speculative network pre-connection — Predict likely config, pre-validate
- [ ] Background refresh coalescing — Single timer for all periodic tasks
- [ ] Lazy peer list loading — Only fetch peers when PeersView visible
- [ ] Energy profiling — Instruments measurement, minimize idle CPU

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Main thread responsiveness | HIGH | MEDIUM | P1 |
| Loading states | HIGH | LOW | P1 |
| Error feedback | HIGH | LOW | P1 |
| Memory stability | HIGH | MEDIUM | P1 |
| Clean shutdown | MEDIUM | MEDIUM | P1 |
| Launch time optimization | MEDIUM | MEDIUM | P2 |
| Animation polish | MEDIUM | LOW | P2 |
| Background task coalescing | MEDIUM | MEDIUM | P2 |
| Memory warning handling | LOW | MEDIUM | P2 |
| Speculative prefetching | LOW | HIGH | P3 |
| Energy profiling | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for acceptable performance (table stakes)
- P2: Should have, improves perceived quality
- P3: Nice to have, advanced optimization

## Swift/SwiftUI-Specific Techniques

### Concurrency Patterns

| Technique | Use Case | Example |
|-----------|----------|---------|
| `@MainActor` | ViewModels, UI updates | `@MainActor class ProcessViewModel` |
| `Task { await ... }` | Async operations from sync context | Button action triggers async work |
| `Task.detached { }` | True background work | File I/O, network calls |
| `await MainActor.run { }` | Return to main thread | Update UI after background work |

### Memory Patterns

| Technique | Use Case | Example |
|-----------|----------|---------|
| `[weak self]` in closures | Break retain cycles | Timer callbacks, Combine sinks |
| `AnyCancellable` storage | Track subscriptions | `var cancellables = Set<AnyCancellable>()` |
| `NSCache` | System-aware caching | Cached images, downloaded binaries |
| Circular buffer | Bounded growth | Log entries with fixed max count |
| `autoreleasepool` | Batch allocations | Loop processing many objects |

### SwiftUI Rendering

| Technique | Use Case | Example |
|-----------|----------|---------|
| `Identifiable` | Stable row identity | `PeerInfo: Identifiable` |
| `Equatable` | Prevent unnecessary rebuilds | Custom `==` for complex models |
| `@StateObject` vs `@ObservedObject` | View-owned vs external state | ViewModel lifecycle |
| `LazyVStack` | Large lists | Only render visible rows |
| `task {}` modifier | View lifecycle async work | Load data when view appears |

### Process/Timer Management

| Technique | Use Case | Example |
|-----------|----------|---------|
| Process termination handling | Clean subprocess exit | `process.terminationHandler` |
| Timer with RunLoop | Periodic polling | Peer info fetching |
| `Timer.scheduledTimer(withTimeInterval:)` | Modern timer API | Avoid `Timer(timeInterval:)` |
| Debouncing | Batch rapid changes | Config saves, search input |

## Current Codebase Assessment

### Already Implemented

- ✓ `@MainActor` on ProcessViewModel
- ✓ Circular buffer for logs (`maxLogEntries = 100`)
- ✓ ConfigManager debounced saves
- ✓ `AnyCancellable` sets in ViewModels
- ✓ `Identifiable` on PeerInfo

### Needs Verification

- ? Timer invalidation in NetworkRuntime
- ? Process cleanup on app termination
- ? Weak self in all closures
- ? Background queue for file I/O
- ? Main thread safety for all `@Published` updates

### Likely Missing

- ✗ Loading states on button actions
- ✗ Optimistic UI updates
- ✗ Memory warning response
- ✗ Startup time measurement
- ✗ Energy profiling

## Sources

- Apple SwiftUI Performance documentation
- WWDC sessions on Swift Concurrency
- Instruments profiling best practices
- Current codebase architecture analysis (ARCHITECTURE.md)
- Project requirements (PROJECT.md)

---
*Feature research for: Swift/SwiftUI macOS Performance Optimization*
*Researched: 2025-04-24*
