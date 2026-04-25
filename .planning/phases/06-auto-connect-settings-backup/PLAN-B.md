---
wave: 2
depends_on:
  - PLAN-A
files_modified:
  - EasyTierGUI/EasyTierGUIApp.swift
autonomous: true
requirements:
  - AUTO-04
  - AUTO-05
---

# Phase 6 Plan B: Auto-Connect with Network Readiness

**Created:** 2026-04-25
**Phase:** 06-auto-connect-settings-backup

---

## Overview

This plan implements:
1. **AUTO-04**: Network readiness check with 30-second timeout before auto-connect
2. **AUTO-05**: Toast notification with retry button on auto-connect failure

This plan depends on Plan A (ProcessViewModel must have `connectLastUsed()` method).

---

<threat_model>
## Security Threat Model

### Assets
- **Network connectivity state**: NWPathMonitor detects network availability
- **UserDefaults data**: lastConnectedConfigId preference
- **Auto-connect timing**: 30-second timeout window

### Threats
1. **Network state manipulation**: An attacker could manipulate network state to delay or prevent auto-connect
   - **Impact**: Denial of service (auto-connect delayed or canceled)
   - **Likelihood**: Low (requires local network access)

2. **Config ID tampering**: lastConnectedConfigId in UserDefaults could be modified
   - **Impact**: Auto-connect to unintended network configuration
   - **Likelihood**: Low (requires local access to user's machine)

3. **Race condition in network detection**: NWPathMonitor callback and timeout could race
   - **Impact**: Incorrect network state detection
   - **Likelihood**: Low (handled by safeResume guard in implementation)

### Mitigations
1. **No external network calls**: Network readiness uses local NWPathMonitor (no external servers contacted)
2. **Timeout protection**: 30-second maximum wait prevents indefinite blocking
3. **Safe continuation resume**: `safeResume` guard ensures continuation is only resumed once
4. **UUID validation**: lastConnectedConfigId is validated as UUID before use
5. **Config existence check**: `configsContains(id:)` validates config still exists before connecting
6. **Fallback behavior**: If last config is invalid/missing, falls back to connectAll() (no silent failure)

### Residual Risks
- Network state could change between detection and connection attempt (acceptable race condition)
- User may be confused by "network not ready" toast if network flaps (expected UX behavior)

</threat_model>

---

## Task 1: Implement Network Readiness Check

<read_first>
- EasyTierGUI/EasyTierGUIApp.swift (existing auto-connect logic at lines 72-82)
- EasyTierGUI/Services/ProcessViewModel.swift (connectLastUsed method from Plan A)
</read_first>

<action>
Modify `EasyTierGUI/EasyTierGUIApp.swift`:

1. **Add import** at top of file (after existing imports):
   ```swift
   import Network
   ```

2. **Replace existing auto-connect logic** (lines 72-82) with enhanced version:

   **Current code (DELETE):**
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
       let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
       if autoConnect {
           Task {
               // Short delay to let the UI settle before connecting
               try? await Task.sleep(nanoseconds: 800_000_000)
               // Connect all networks
               await processVM.connectAll()
           }
       }
   }
   ```

   **New code (ADD):**
   ```swift
   .onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
       let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
       guard autoConnect else { return }

       Task {
           // Wait for network ready with 30-second timeout
           let networkReady = await waitForNetworkReady(timeout: 30)

           if !networkReady {
               processVM.showToast(
                   "网络未就绪，自动连接已取消",
                   type: .warning,
                   action: ToastAction(title: "重试") {
                       Task { await performAutoConnect(processVM: processVM) }
                   }
               )
               return
           }

           await performAutoConnect(processVM: processVM)
       }
   }
   ```

3. **Add helper functions** at the bottom of EasyTierGUIApp.swift file (inside the struct, before closing brace):

   ```swift
   // MARK: - Auto-Connect Helpers

   /// Perform auto-connect to last used configuration
   private func performAutoConnect(processVM: ProcessViewModel) async {
       // Short delay to let the UI settle
       try? await Task.sleep(nanoseconds: 800_000_000)

       // Try to connect last used config
       let connected = await processVM.connectLastUsed()

       if !connected {
           // No last config or config no longer exists
           // Fallback: connect all (existing behavior)
           await processVM.connectAll()
       }
   }

   /// Wait for network to become ready with timeout
   /// Uses NWPathMonitor to detect network connectivity
   private func waitForNetworkReady(timeout: TimeInterval) async -> Bool {
       await withCheckedContinuation { continuation in
           let monitor = NWPathMonitor()
           var resumed = false

           // Ensure we only resume once
           let safeResume = { (result: Bool) in
               guard !resumed else { return }
               resumed = true
               monitor.cancel()
               continuation.resume(returning: result)
           }

           monitor.pathUpdateHandler = { path in
               if path.status == .satisfied {
                   safeResume(true)
               }
           }

           monitor.start(queue: DispatchQueue.global())

           // Timeout fallback
           DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
               safeResume(false)
           }
       }
   }
   ```
</action>

<acceptance_criteria>
- EasyTierGUIApp.swift contains `import Network`
- EasyTierGUIApp.swift contains `func waitForNetworkReady(timeout: TimeInterval) async -> Bool`
- EasyTierGUIApp.swift contains `func performAutoConnect(processVM:) async`
- Auto-connect logic reads `UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")`
- Auto-connect logic reads `UserDefaults.standard.string(forKey: "lastConnectedConfigId")` via `connectLastUsed()`
- Network timeout is 30 seconds (hardcoded value)
- On network timeout, shows Toast with type `.warning` and action "重试"
- Calls `processVM.connectLastUsed()` instead of `connectAll()`
- Falls back to `connectAll()` if no last config found
- File compiles without errors
</acceptance_criteria>

---

## Verification

After task complete, verify:

1. **Build succeeds**:
   ```bash
   xcodebuild -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug build 2>&1 | grep -i error || echo "Build succeeded"
   ```

2. **Manual test - Network readiness**:
   - Enable auto-connect in Settings
   - Disconnect network (WiFi off)
   - Launch app
   - Verify Toast shows "网络未就绪，自动连接已取消" with retry button
   - Reconnect network
   - Click retry button
   - Verify connection starts

3. **Manual test - Last config memory**:
   - Connect to a specific config
   - Quit app
   - Launch app with auto-connect enabled
   - Verify it connects to the same config (not all configs)

4. **Manual test - No last config**:
   - Fresh install (clear UserDefaults)
   - Enable auto-connect
   - Launch app
   - Verify it connects all configs (fallback behavior)

---

## Requirements Traceability

| Requirement | Task(s) |
|-------------|---------|
| AUTO-04 | Task 1 (waitForNetworkReady with 30s timeout) |
| AUTO-05 | Task 1 (Toast with retry action) |

---

## Dependencies

| Dependency | Source | Notes |
|------------|--------|-------|
| `connectLastUsed()` | Plan A Task 2 | Must be implemented first |
| `showToast()` | Phase 1 | Already exists |
| `ToastAction` | Models.swift | Already exists |
| NWPathMonitor | Network.framework | System framework |

---

*Plan created: 2026-04-25*
