---
wave: 2
depends_on:
  - 01-PLAN.md
files_modified:
  - EasyTierGUI/Services/ProcessViewModel.swift
  - EasyTierGUI/Views/ConnectionView.swift
autonomous: true
requirements:
  - INT-01
  - INT-02
  - INT-05
  - D-03
  - D-04
---

# Plan 1.2: Button Loading States

**Goal:** Every action shows immediate visual acknowledgment with ProgressView + disabled state during operations.

## Problem Statement

Currently the connect/disconnect buttons in `ConnectionView` don't show immediate loading state. Users can spam-click buttons. The status badge shows "连接中" but only after the runtime status changes, not immediately on button click.

## Solution

1. Add `isConnecting` and `isDisconnecting` states to `NetworkRuntime`
2. Set these states immediately when user clicks button
3. Show ProgressView inside button during operation
4. Disable button during operation
5. Update button text to "连接中..." / "断开中..."

## Tasks

### Task 1: Add operation states to NetworkRuntime

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Add two new `@Published` properties to `NetworkRuntime` class (line ~20, after `peers`):

```swift
@Published var isConnecting: Bool = false
@Published var isDisconnecting: Bool = false
```

These will track per-network operation states independently from the `status` property.
</action>

<acceptance_criteria>
- `NetworkRuntime` class contains `@Published var isConnecting: Bool = false`
- `NetworkRuntime` class contains `@Published var isDisconnecting: Bool = false`
</acceptance_criteria>

---

### Task 2: Update connect method to set loading state

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Modify `NetworkRuntime.connect(config:)` method (line ~60) to set `isConnecting = true` at the start and `isConnecting = false` when complete:

```swift
func connect(config: EasyTierConfig) async {
    isConnecting = true
    defer { isConnecting = false }
    
    status = .connecting
    errorMessage = nil
    onStateChange?()

    do {
        try await service.start(config: config)
    } catch {
        errorMessage = error.localizedDescription
        status = .error
        onStateChange?()
    }
}
```

The `defer` block ensures `isConnecting` is reset even if an error occurs.
</action>

<acceptance_criteria>
- `connect` method sets `isConnecting = true` at the start
- `connect` method uses `defer { isConnecting = false }` to ensure reset
- Loading state is visible immediately when user clicks connect
</acceptance_criteria>

---

### Task 3: Update disconnect method to set loading state

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Modify `NetworkRuntime.disconnect()` method (line ~74) to set `isDisconnecting = true` at the start:

```swift
func disconnect() async {
    isDisconnecting = true
    defer { isDisconnecting = false }
    
    do {
        try await service.stop()
        errorMessage = nil
    } catch {
        errorMessage = error.localizedDescription
        status = .error
        onStateChange?()
    }
}
```
</action>

<acceptance_criteria>
- `disconnect` method sets `isDisconnecting = true` at the start
- `disconnect` method uses `defer { isDisconnecting = false }` to ensure reset
</acceptance_criteria>

---

### Task 4: Add helper methods to ProcessViewModel for operation states

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Add helper methods in `ProcessViewModel` to check operation states for a config (add after `isRunning` method, around line 260):

```swift
// MARK: - Operation State Helpers

func isConnecting(_ config: EasyTierConfig) -> Bool {
    runtimeIfExists(for: config.id)?.isConnecting ?? false
}

func isDisconnecting(_ config: EasyTierConfig) -> Bool {
    runtimeIfExists(for: config.id)?.isDisconnecting ?? false
}

func isOperating(_ config: EasyTierConfig) -> Bool {
    isConnecting(config) || isDisconnecting(config)
}
```
</action>

<acceptance_criteria>
- `ProcessViewModel` contains `func isConnecting(_ config: EasyTierConfig) -> Bool`
- `ProcessViewModel` contains `func isDisconnecting(_ config: EasyTierConfig) -> Bool`
- `ProcessViewModel` contains `func isOperating(_ config: EasyTierConfig) -> Bool`
</acceptance_criteria>

---

### Task 5: Update ConnectionView button with loading state

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Views/ConnectionView.swift
</read_first>

<action>
Modify the connect/disconnect button in `ConfigListSection` (line ~341) to show loading state and be disabled during operations:

Replace the existing button (lines 341-360) with:

```swift
// Connect/Disconnect button
let isConnectingNow = vm.isConnecting(config)
let isDisconnectingNow = vm.isDisconnecting(config)
let isOperating = vm.isOperating(config)

Button(action: {
    if isRunning {
        Task { await vm.disconnect(configID: config.id) }
    } else {
        if let msg = validateConfig(config) {
            validationMessage = msg
            showValidationAlert = true
        } else {
            Task { await connect(config) }
        }
    }
}) {
    HStack(spacing: 4) {
        if isOperating {
            ProgressView()
                .controlSize(.small)
        }
        Text(isConnectingNow ? "连接中..." : (isDisconnectingNow ? "断开中..." : (isRunning ? "断开" : "连接")))
    }
    .font(.system(size: 12, weight: .medium))
    .frame(minWidth: 60)
}
.buttonStyle(.plain)
.padding(.horizontal, 14)
.padding(.vertical, 6)
.background(isRunning ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12))
.foregroundColor(isRunning ? .red : .accentColor)
.cornerRadius(6)
.disabled(isOperating)
.opacity(isOperating ? 0.6 : 1)
```

Also update the delete button to be disabled during operations:

```swift
// Delete button - add isOperating to disabled condition
.disabled(isRunning || isOperating || vm.configManager.configs.count <= 1)
.opacity((isRunning || isOperating || vm.configManager.configs.count <= 1) ? 0.3 : 1)
```
</action>

<acceptance_criteria>
- Button shows `ProgressView()` when `isOperating` is true
- Button text changes to "连接中..." or "断开中..." during operation
- Button is disabled (`disabled(isOperating)`) during operation
- Button opacity changes to 0.6 during operation
- Delete button is disabled during connect/disconnect operations
</acceptance_criteria>

---

### Task 6: Update batch operation buttons with loading states

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Views/ConnectionView.swift
</read_first>

<action>
Add a computed property or state to track if any network is currently operating. Update the "全部连接" and "全部断开" buttons (lines 221-251) to show loading state:

Add state variable:
```swift
@State private var isConnectingAll = false
@State private var isDisconnectingAll = false
```

Update the batch connect button:
```swift
Button(action: { 
    isConnectingAll = true
    Task {
        await connectAll()
        isConnectingAll = false
    }
}) {
    HStack(spacing: 4) {
        if isConnectingAll {
            ProgressView().controlSize(.small)
        }
        Image(systemName: isConnectingAll ? "" : "link")
        Text(isConnectingAll ? "连接中..." : "全部连接")
    }
    .font(.system(size: 11, weight: .medium))
}
.buttonStyle(.plain)
.padding(.horizontal, 10)
.padding(.vertical, 5)
.background(Color.green.opacity(0.1))
.foregroundColor(.green)
.cornerRadius(6)
.disabled(vm.configManager.configs.isEmpty || vm.isAnyNetworkRunning || isConnectingAll)
.opacity((vm.configManager.configs.isEmpty || vm.isAnyNetworkRunning || isConnectingAll) ? 0.5 : 1)
```

Similarly update the "全部断开" button with `isDisconnectingAll` state.
</action>

<acceptance_criteria>
- "全部连接" button shows `ProgressView` and "连接中..." during batch connect
- "全部断开" button shows `ProgressView` and "断开中..." during batch disconnect
- Both buttons are disabled during their respective operations
</acceptance_criteria>

---

## Verification

1. Build and run the application
2. Click "连接" button - verify immediate ProgressView appears
3. Verify button text changes to "连接中..."
4. Verify button is disabled (cannot click again)
5. Click "断开" button - verify immediate ProgressView appears
6. Verify "全部连接" and "全部断开" show loading states
7. Verify no spinning beach ball during any operation

## must_haves

- [ ] `NetworkRuntime.isConnecting` and `isDisconnecting` properties exist
- [ ] `connect()` sets `isConnecting = true` immediately, resets on completion
- [ ] `disconnect()` sets `isDisconnecting = true` immediately, resets on completion
- [ ] Button shows `ProgressView` during operation
- [ ] Button text changes to "连接中..." / "断开中..."
- [ ] Button is disabled during operation
- [ ] Delete button is disabled during operations
