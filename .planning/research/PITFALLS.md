# Pitfalls Research

**Domain:** Swift/SwiftUI macOS Desktop Application Performance Optimization
**Researched:** 2025-04-24
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Main Thread Blocking During Process Spawn

**What goes wrong:**
Spawning a `Process` or calling `PrivilegedExecutor.runCommand()` directly on the main thread blocks the UI, causing the spinning beach ball. The Authorization Services dialog itself can block while waiting for user input.

**Why it happens:**
Developers often call process management methods synchronously from UI event handlers. Even with `@MainActor`, synchronous operations will block. Authorization prompts are inherently blocking operations.

**How to avoid:**
- Wrap privileged execution in `withCheckedThrowingContinuation` and dispatch to a background queue
- Use `Task { }` with proper actor isolation for async process operations
- Never call `Process.run()` or `PrivilegedExecutor.runCommand()` directly from UI code

**Warning signs:**
- Beach ball appears when clicking "Connect" button
- `Process.run()` called from a `@MainActor` context without async indirection
- `DispatchQueue.main.async` used but the blocking operation is still on main queue

**Phase to address:** Phase 1 (Startup & Responsiveness)

**Evidence in codebase:**
`EasyTierService.swift:115-125` already implements this correctly with `withCheckedThrowingContinuation` and `DispatchQueue.global(qos: .userInitiated).async`.

---

### Pitfall 2: Timer Retain Cycles and Leaked Timers

**What goes wrong:**
`Timer.scheduledTimer` retains its target, creating retain cycles. If the timer isn't properly invalidated when the owning object is deallocated, it continues firing and calling methods on a partially deallocated object.

**Why it happens:**
Developers forget to invalidate timers in `deinit`, or the timer captures `self` strongly in its closure without using `[weak self]`.

**How to avoid:**
- Always invalidate timers in `deinit`
- Always use `[weak self]` in timer closures
- For `@MainActor` classes, remember `deinit` cannot be actor-isolated, so timer cleanup must be dispatched to main queue

**Warning signs:**
- Timer callback crashes with EXC_BAD_ACCESS
- Memory not releasing after view disappears
- Timer continuing to fire after network disconnect

**Phase to address:** Phase 2 (Memory Stability)

**Evidence in codebase:**
`NetworkRuntime.swift:52-56` - `deinit` invalidates timer correctly, but the timer closure at line 93 uses `[weak self]` which is correct. However, `stopPrivilegedLogPolling` dispatches to main queue for invalidation (line 577-580), which is necessary since the timer may have been scheduled on the main run loop.

---

### Pitfall 3: SwiftUI View Identity Causing Unnecessary Re-renders

**What goes wrong:**
Using `.id()` modifier with unstable identifiers causes SwiftUI to destroy and recreate views unnecessarily. Using index-based `ForEach` without stable identifiers can cause state loss.

**Why it happens:**
Developers use array indices as identifiers in `ForEach`, or use UUID-based `.id()` modifiers that change on parent re-renders. SwiftUI sees a new identity and rebuilds the entire view subtree.

**How to avoid:**
- Use `Identifiable` protocol with stable IDs for collection items
- Avoid `.id()` modifiers that change frequently
- Be careful with `onAppear` - it can fire multiple times during scroll or navigation

**Warning signs:**
- Form fields resetting unexpectedly
- Scroll position jumping
- UI flickering during state updates

**Phase to address:** Phase 1 (Startup & Responsiveness)

**Evidence in codebase:**
`ConnectionView.swift:25` uses `.id(config.id)` on ConfigFormView - this is correct since config.id is stable. `LogView.swift:38` uses `.id(runtime.id)` which is also stable.

---

### Pitfall 4: Combine Subscription Accumulation

**What goes wrong:**
`AnyCancellable` stored in a `Set<AnyCancellable>` but subscriptions created in methods that get called multiple times accumulate without cleanup. Each call adds a new subscription.

**Why it happens:**
Developers create subscriptions inside methods like `onAppear` or computed properties without checking if a subscription already exists. The cancellables set grows indefinitely.

**How to avoid:**
- Create subscriptions once in `init()` when possible
- Use `.prefix(1)` or `.removeDuplicates()` to limit subscription activity
- Consider using `ObservableObject`'s built-in change tracking instead of manual Combine subscriptions

**Warning signs:**
- Callback firing multiple times for a single event
- Memory growing slowly over time
- Subscription closures capturing stale state

**Phase to address:** Phase 2 (Memory Stability)

**Evidence in codebase:**
`NetworkRuntime.swift:34-49` creates subscriptions in `init()` which is correct pattern. `ProcessViewModel.swift:153-170` also creates subscriptions in `init()`.

---

### Pitfall 5: DispatchQueue.main.async Overuse in @MainActor Context

**What goes wrong:**
Using `DispatchQueue.main.async` inside `@MainActor` methods is redundant and can cause unexpected ordering issues. The code is already guaranteed to run on main thread.

**Why it happens:**
Developers don't trust `@MainActor` or are migrating old code that used manual dispatch. They add extra dispatch calls "to be safe".

**How to avoid:**
- Remove `DispatchQueue.main.async` calls from `@MainActor` methods
- Trust the Swift concurrency system
- Only use explicit dispatch when bridging from non-MainActor code

**Warning signs:**
- `DispatchQueue.main.async` inside a method marked `@MainActor`
- Nested `DispatchQueue.main.async` calls
- State updates happening out of expected order

**Phase to address:** Phase 1 (Startup & Responsiveness)

**Evidence in codebase:**
`EasyTierService.swift:517-519` - `publishRunning` uses `DispatchQueue.main.async` which is appropriate since `EasyTierService` is NOT marked `@MainActor`. However, `ProcessViewModel` methods that call these from `@MainActor` context don't need additional dispatch.

---

### Pitfall 6: onAppear for Expensive Initialization

**What goes wrong:**
Putting expensive synchronous operations in `onAppear` blocks the view from appearing, or causes operations to run multiple times as views scroll in/out of visibility.

**Why it happens:**
`onAppear` feels like the right place for initialization, but SwiftUI calls it whenever the view enters the visible hierarchy, not just once. In scrollable views, this can happen frequently.

**How to avoid:**
- Use `.task` modifier for async work instead of `onAppear`
- For one-time initialization, use `@StateObject` initialization or explicit state flags
- Debounce or check if already initialized before re-running

**Warning signs:**
- View appearing delayed or with blank state
- Network requests firing multiple times
- Console logs showing repeated initialization

**Phase to address:** Phase 1 (Startup & Responsiveness)

**Evidence in codebase:**
`ConnectionView.swift:45-49` uses `onAppear` to set `editingConfig` - this is lightweight and acceptable. `EasyTierGUIApp.swift:69-71` uses `onAppear` to set `appDelegate.processVM` which is also acceptable.

---

### Pitfall 7: Log/Array Unbounded Growth

**What goes wrong:**
`@Published` arrays that grow without bound cause memory growth and slower UI updates. SwiftUI must diff larger arrays on each change.

**Why it happens:**
Developers append to arrays without implementing pruning logic. The circular buffer pattern is often forgotten.

**How to avoid:**
- Implement maximum size limits with removal of oldest entries
- Use `removeFirst()` when over limit: `if array.count > max { array.removeFirst(array.count - max) }`
- Consider lazy loading for large lists

**Warning signs:**
- Memory growing linearly over time
- UI becoming sluggish after extended use
- `@Published` array used for logs without size limit

**Phase to address:** Phase 2 (Memory Stability)

**Evidence in codebase:**
`EasyTierService.swift:65-66` correctly defines `maxLogEntries = 100` and `maxLogMessageLength = 2000`. `EasyTierService.swift:388-390` correctly removes old entries when over limit.

---

### Pitfall 8: NSAlert.runModal() Blocking Main Thread

**What goes wrong:**
Calling `NSAlert.runModal()` blocks the main thread and prevents the app from responding to other events. This can cause beach balls or prevent proper app termination.

**Why it happens:**
`runModal()` is the standard AppKit API, but it's a blocking call. For non-critical alerts, this can feel unresponsive.

**How to avoid:**
- For non-critical alerts, consider using SwiftUI native `.alert()` modifier
- Use `beginSheetModal` for window-attached alerts instead of app-modal
- Reserve `runModal()` for truly blocking situations like critical errors

**Warning signs:**
- App unresponsive while alert is shown
- Menu bar items not updating during alert
- Background timers not firing during alert

**Phase to address:** Phase 1 (Startup & Responsiveness)

**Evidence in codebase:**
`EasyTierGUIApp.swift:282-301` uses `alert.runModal()` for authorization error. This is acceptable for a critical error that blocks app usage, but could be improved with SwiftUI native alert.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `DispatchQueue.main.async` everywhere | "Safe" threading | Redundant dispatch, ordering issues | When bridging from non-MainActor code |
| Index-based `ForEach` | Simpler code | State loss on reorder/delete | Never - use Identifiable |
| `@Published` for all state | Automatic UI updates | Excessive re-renders | Only for state that actually affects UI |
| Global singleton ViewModels | Easy access | Hard to test, hidden dependencies | Small apps only |
| Skip `deinit` cleanup | Less code | Memory leaks, zombie timers | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Process spawning | Call `run()` on main thread | Use background queue with continuation |
| Authorization Services | Assume success after one prompt | Check `isAuthorizedCached()` before privileged ops |
| FileHandle readability | Forget to nil the handler | Set `readabilityHandler = nil` in cleanup |
| NSStatusBar | Create multiple status items | Use singleton pattern with single item |
| UserDefaults | Read on every view render | Use `@AppStorage` for cached access |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Large `@Published` arrays | Slow UI, memory growth | Implement circular buffer | >100 items in logs |
| Timer without weak self | Memory leak, crashes | Always use `[weak self]` | Any timer with closure |
| `onChange` without debounce | Rapid state updates | Add debounce with Task.sleep | Typing in search fields |
| LazyVStack in small lists | Overhead without benefit | Use VStack for small lists | <50 items |
| Regex compilation in hot path | CPU spikes | Compile regex once as static | Called >10 times/second |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing passwords in UserDefaults | Credential exposure | Use Keychain for secrets |
| Shell command injection | Arbitrary code execution | Use argument arrays, never string interpolation |
| Executable path from user input | Path traversal | Validate path exists and is expected executable |
| Authorization prompt on every action | User fatigue | Cache authorization reference |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No loading state on connect | User clicks multiple times | Show ProgressView during operation |
| Generic error messages | User confused | Show actionable error with context |
| Silent failures | User unaware of issues | Show Toast/Alert for operation outcomes |
| Blocking operations | Beach ball, app feels slow | Move to background, show progress |

## "Looks Done But Isn't" Checklist

- [ ] **Timer cleanup:** Often missing `invalidate()` in `deinit` — verify all Timer properties are nil'd
- [ ] **FileHandle cleanup:** Often missing `readabilityHandler = nil` — verify in stop() methods
- [ ] **Combine subscriptions:** Often accumulating — verify subscriptions are in `init()` not methods
- [ ] **Memory release:** Often holding references — verify `[weak self]` in all closures
- [ ] **Error feedback:** Often silent failures — verify all error paths show user feedback
- [ ] **Loading states:** Often missing — verify buttons show progress during async operations

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Timer retain cycle | LOW | Add `deinit` with `timer?.invalidate()` |
| Main thread blocking | MEDIUM | Wrap in `Task.detached` or background queue |
| Subscription leak | MEDIUM | Move subscription creation to `init()` |
| Unbounded array | LOW | Add circular buffer logic |
| Missing loading state | LOW | Add `isLoading` state and ProgressView |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Main thread blocking | Phase 1 | Instruments Time Profiler shows no main thread stalls |
| Timer retain cycles | Phase 2 | Xcode Memory Graph shows no leaked timers |
| View identity issues | Phase 1 | No view reconstruction logs on state change |
| Combine accumulation | Phase 2 | `cancellables.count` stable over time |
| DispatchQueue overuse | Phase 1 | Code review removes redundant dispatch calls |
| onAppear expensive init | Phase 1 | One-time initialization verified with breakpoints |
| Log unbounded growth | Phase 2 | Memory stable after 1 hour runtime with logs |
| NSAlert blocking | Phase 1 | UI remains responsive during error display |

## Sources

- Apple Developer Documentation: Swift Concurrency, MainActor
- Apple Developer Documentation: Timer and Memory Management
- SwiftUI Performance sessions (WWDC 2020-2024)
- Hacking with Swift: Understanding @StateObject vs @ObservedObject
- Swift by Sundell: Combine memory management patterns
- Codebase analysis of EasyTierGUI (2025-04-24)
- Personal experience with SwiftUI macOS application optimization

---
*Pitfalls research for: Swift/SwiftUI macOS Performance Optimization*
*Researched: 2025-04-24*
