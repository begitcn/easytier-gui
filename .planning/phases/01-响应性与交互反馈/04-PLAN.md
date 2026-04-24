---
wave: 4
depends_on:
  - 03-PLAN.md
files_modified:
  - EasyTierGUI/EasyTierGUIApp.swift
  - EasyTierGUI/Services/ProcessViewModel.swift
autonomous: true
requirements:
  - STAB-03
  - D-02
  - D-07
---

# Plan 1.4: Authorization Error Handling

**Goal:** Replace blocking NSAlert for authorization failures with Toast notification + retry option. Implement delayed authorization pattern where auth dialog only appears when user clicks connect.

## Problem Statement

Currently `EasyTierGUIApp.swift` shows a blocking `NSAlert.runModal()` when authorization fails (line 282-301). Per D-02, authorization should be delayed until user connects. Per D-07, authorization denial should show toast with retry option.

## Solution

1. Remove blocking `NSAlert.runModal()` for authorization errors
2. Use toast notification with retry button for auth failures
3. Keep authorization check silent at startup (just cache status)
4. Show authorization prompt only when user tries to connect

## Tasks

### Task 1: Remove blocking authorization error alert

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/EasyTierGUIApp.swift
</read_first>

<action>
Replace the `showAuthorizationError` method (lines 282-301) with a toast-based approach:

```swift
private func showAuthorizationError(message: String? = nil) {
    // Use toast notification instead of blocking NSAlert
    let defaultMessage = "需要管理员权限来创建虚拟网络设备。\n\n您可以：\n• 点击「重试」重新授权\n• 使用终端启动: sudo EasyTierGUI"
    
    processVM?.showToast(
        message ?? defaultMessage,
        type: .error,
        action: ToastAction(title: "重试") { [weak self] in
            self?.authorizeCurrentSession()
        }
    )
}
```

This replaces the blocking `alert.runModal()` with a non-blocking toast that includes a retry button.
</action>

<acceptance_criteria>
- `showAuthorizationError` no longer uses `NSAlert.runModal()`
- `showAuthorizationError` calls `processVM?.showToast()` with error message
- Toast includes `ToastAction` with "重试" button that calls `authorizeCurrentSession()`
</acceptance_criteria>

---

### Task 2: Make startup authorization check silent

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/EasyTierGUIApp.swift
</read_first>

<action>
Modify `checkRootPrivileges` method (lines 262-270) to be silent - only cache authorization status, don't show prompt:

```swift
private func checkRootPrivileges() {
    // Check if running as root (uid 0)
    let uid = getuid()
    if uid != 0 {
        // Silently cache authorization status without showing prompt
        // User will see authorization dialog when they try to connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Just check if we have cached authorization, don't prompt
            _ = PrivilegedSessionManager.shared.isAuthorizedCached()
        }
    }
}
```

Remove the call to `authorizeCurrentSession()` here. The authorization will be requested when user tries to connect (in `EasyTierService.startPrivileged`).
</action>

<acceptance_criteria>
- `checkRootPrivileges` does not call `authorizeCurrentSession()`
- `checkRootPrivileges` only calls `PrivilegedSessionManager.shared.isAuthorizedCached()` to cache status
- No authorization dialog appears at app startup
</acceptance_criteria>

---

### Task 3: Add authorization status helper to ProcessViewModel

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Add a method to check and request authorization in `ProcessViewModel`. Add to `// MARK: - Connection Control` section:

```swift
// MARK: - Authorization

var isAuthorized: Bool {
    PrivilegedSessionManager.shared.isAuthorizedCached()
}

func requestAuthorization() {
    do {
        try PrivilegedSessionManager.shared.ensureAuthorized()
    } catch {
        showToast("授权失败：\(error.localizedDescription)", type: .error)
    }
}
```

This provides a centralized way for views to check/request authorization.
</action>

<acceptance_criteria>
- `ProcessViewModel` contains `var isAuthorized: Bool` computed property
- `ProcessViewModel` contains `func requestAuthorization()` method
- Authorization failures show toast notification
</acceptance_criteria>

---

### Task 4: Update connect flow to handle authorization

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
The current `EasyTierService.startPrivileged()` already handles authorization via `PrivilegedSessionManager.shared.run()`. The error from authorization failure will propagate up through the existing error handling in `NetworkRuntime.connect()`.

Ensure the error message is user-friendly. The `EasyTierError.requiresPrivileges` case already has a good message. No changes needed here - the error will flow through to the toast system implemented in Plan 1.3.

However, we should add a specific check before connecting to give users a clearer message. Modify `connect(configID:)` method (line 299):

```swift
func connect(configID: UUID) async {
    guard let config = configManager.configs.first(where: { $0.id == configID }) else { return }
    let runtime = ensureRuntime(for: configID)

    // Check if authorized (non-blocking check)
    if getuid() != 0 && !PrivilegedSessionManager.shared.isAuthorizedCached() {
        // Will trigger authorization dialog when service.start is called
        // This is expected behavior
    }

    // 检查内核是否存在
    guard easytierCoreExists else {
        runtime.errorMessage = "未找到 easytier-core，请在设置中配置正确的 EasyTier 目录。"
        runtime.status = .error
        showToast("未找到 easytier-core，请在设置中配置正确的 EasyTier 目录。", type: .error)
        refreshOverallStatus()
        return
    }

    // ... rest of existing method
}
```

Add the `showToast` call to provide toast feedback for missing core as well.
</action>

<acceptance_criteria>
- `connect(configID:)` shows toast for missing core error
- Authorization errors flow through to toast via existing error handling
</acceptance_criteria>

---

### Task 5: Ensure authorization toast shows retry action

<read_first>
- /Users/chaogeek/XcodeProjects/easytier-gui/EasyTierGUI/Services/ProcessViewModel.swift
</read_first>

<action>
Modify `NetworkRuntime.connect()` to show toast with retry action for authorization failures:

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
        
        // Show toast with retry for authorization errors
        if let easyTierError = error as? EasyTierError, easyTierError == .requiresPrivileges {
            // This case is handled by the parent view model
        }
    }
}
```

The actual retry action is handled in `EasyTierGUIApp.showAuthorizationError`. No additional changes needed here since errors bubble up through `ProcessViewModel.connect(configID:)`.

Add toast notification in `ProcessViewModel.connect(configID:)` for authorization errors:

After the `await runtime.connect(config: config)` call, check for authorization errors:

```swift
await runtime.connect(config: config)
refreshOverallStatus()

// Show toast with retry for authorization errors
if runtime.status == .error, let error = runtime.errorMessage, error.contains("授权") || error.contains("权限") {
    showToast(error, type: .error, action: ToastAction(title: "重试") { [weak self] in
        guard let self = self else { return }
        Task { await self.connect(configID: configID) }
    })
}
```
</action>

<acceptance_criteria>
- Authorization failures show toast with "重试" button
- Clicking retry re-attempts the connection
- Connection errors show toast notification
</acceptance_criteria>

---

## Verification

1. Build and run the application
2. Verify no authorization dialog appears at startup
3. Click "连接" button on a configuration
4. Verify authorization dialog appears (if not already authorized)
5. Click "拒绝" on authorization dialog
6. Verify toast appears with error message and "重试" button
7. Click "重试" - verify authorization dialog appears again
8. Authorize and verify connection succeeds

## must_haves

- [ ] No `NSAlert.runModal()` for authorization errors
- [ ] `showAuthorizationError` uses toast notification with retry button
- [ ] `checkRootPrivileges` is silent (no prompt at startup)
- [ ] Authorization dialog only appears when connecting
- [ ] Authorization denial shows toast with retry action
- [ ] `ProcessViewModel.isAuthorized` property exists
- [ ] `ProcessViewModel.requestAuthorization()` method exists
