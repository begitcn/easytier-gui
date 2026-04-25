# Phase 6 Research: Auto-Connect & Settings Backup

**Research Date:** 2026-04-25
**Phase:** 06-auto-connect-settings-backup

---

## Overview

This document identifies what we need to know to plan Phase 6 implementation: Auto-Connect & Settings Backup (AUTO-01~AUTO-05, SETT-01~SETT-03).

---

## Requirement Analysis

### Auto-Connect Requirements

| ID | Requirement | Current State | Implementation Notes |
|----|-------------|---------------|----------------------|
| AUTO-01 | Toggle auto-connect on startup | ✅ Existing | `@AppStorage("autoConnectOnLaunch")` in SettingsView.swift |
| AUTO-02 | Remember last-used config | ❌ Missing | Need to store `lastConnectedConfigId` |
| AUTO-03 | Launch at login when auto-connect enabled | ✅ Existing | OpenAtLoginManager + SMAppService |
| AUTO-04 | Network readiness check before connecting | ❌ Missing | Need NWPathMonitor with 30s timeout |
| AUTO-05 | Notification on auto-connect failure | ⚠️ Partial | Toast exists, need retry action |

### Settings Backup Requirements

| ID | Requirement | Current State | Implementation Notes |
|----|-------------|---------------|----------------------|
| SETT-01 | Backup all configs + preferences | ❌ Missing | New BackupService.swift |
| SETT-02 | Restore from backup file | ❌ Missing | Import logic already exists |
| SETT-03 | Conflict resolution options | ❌ Missing | Per D-05, use direct overwrite |

---

## Key Technical Questions

### Q1: Where to store `lastConnectedConfigId`?

**Options:**
- AppStorage in SettingsView.swift
- ConfigManager (centralized config management)
- ProcessViewModel (runtime coordination)

**Recommendation:** AppStorage in ProcessViewModel or EasyTierGUIApp for global access. Looking at existing patterns, `@AppStorage("autoConnectOnLaunch")` is used in SettingsView.swift. We should follow the same pattern.

**Files to modify:**
- EasyTierGUIApp.swift — Read/write lastConnectedConfigId
- SettingsView.swift — Optionally show last connected config name

### Q2: How to implement network readiness check?

**Options:**
1. **NWPathMonitor** — Apple's Network framework, monitors path changes
2. **Simple reachability check** — Attempt connection to known host
3. **Combined approach** — Wait for path to be satisfied, then attempt connection

**Recommendation:** Use `NWPathMonitor` from Network.framework:
- Monitor network path status
- Wait for `.satisfied` status with 30-second timeout
- Fall back to timeout even if network not fully ready

**Key APIs:**
```swift
import Network
let monitor = NWPathMonitor()
monitor.pathUpdateHandler = { path in
    // path.status == .satisfied means network available
}
monitor.start(queue: DispatchQueue.global())
```

### Q3: Backup file format and storage?

**Per D-04 in context:**
- JSON format with `configs` and `preferences` fields
- File naming: `EasyTierGUI-Backup-{日期}.json`
- Default save location: User's Documents folder (via NSSavePanel)
- Load location: User-selected file (via NSOpenPanel)

**Structure:**
```json
{
  "version": "1.0",
  "timestamp": "2026-04-25T10:00:00Z",
  "configs": [...],
  "preferences": {
    "startAtLogin": false,
    "showMenuBar": true,
    "autoConnectOnLaunch": false,
    "showDockIcon": true,
    "enableLogMonitoring": false
  }
}
```

### Q4: Which AppStorage keys need to be backed up?

Current AppStorage keys (from SettingsView.swift):
- `startAtLogin` — Bool
- `showMenuBar` — Bool
- `autoConnectOnLaunch` — Bool
- `showDockIcon` — Bool
- `enableLogMonitoring` — Bool

**Note:** These are user preference toggles, not sensitive data.

### Q5: How to handle backup restore conflicts?

**Per D-05 decision:** Direct overwrite mode (simpler than SETT-03's conflict options)

This means:
- All existing configs are replaced
- All preferences are replaced
- No merge or skip options needed for v1

**Implementation:** Use existing import logic from ConfigManager, overwrite UserDefaults preferences after validation.

---

## Integration Points

### EasyTierGUIApp.swift (Auto-Connect Logic)

**Current logic (lines 72-82):**
```swift
.onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
    let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
    if autoConnect {
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await processVM.connectAll()  // Currently connects ALL configs
        }
    }
}
```

**Changes needed:**
1. Read `lastConnectedConfigId` from UserDefaults
2. Wait for network ready (NWPathMonitor)
3. Connect only the last-used config
4. Show Toast on failure with retry action

### SettingsView.swift (Backup UI)

**Add:**
- Backup button → opens NSSavePanel, saves to selected location
- Restore button → opens NSOpenPanel, loads and applies backup
- Optional: Show last connected config name

### New Files Needed

| File | Purpose |
|------|---------|
| `BackupService.swift` | Handle backup/restore operations |

**BackupService responsibilities:**
- `backup(to: URL)` — Export configs + preferences
- `restore(from: URL)` — Import and apply backup
- `preferencesBackupData()` — Gather all AppStorage values

---

## Implementation Dependencies

1. **Phase 1 (Toast)** — Used for AUTO-05 notifications
2. **Phase 4 (Import/Export)** — ConfigManager already has import/export methods, can reuse
3. **Existing Settings** — Auto-connect toggle, login item manager already exist

---

## Risk Factors

1. **Network monitor on VPN:** NWPathMonitor may report satisfied even when VPN is down but physical network is up — acceptable for "network ready" semantics
2. **Backup file security:** JSON contains config passwords if not excluded — document that users should handle backup files securely
3. **Restore with active connections:** Should disconnect all before restore? — Yes, to avoid port conflicts

---

## Questions for Decision

1. **Backup location:** Default to Documents folder, or remember last used location?
2. **Backup file extension:** `.json` or `.easytierbak`? (JSON is more standard)
3. **Auto-connect retry:** Should it retry automatically once after network becomes ready, or wait for user action? — Per D-03, use Toast with retry button

---

## References

- **SettingsView.swift:** Lines 17-21 (AppStorage keys), lines 79 (autoConnectOnLaunch toggle), lines 290-310 (OpenAtLoginManager)
- **EasyTierGUIApp.swift:** Lines 72-82 (current auto-connect logic)
- **ProcessViewModel.swift:** Lines 379-390 (connectAll), lines 409-459 (connect with error handling)
- **ConfigManager.swift:** Lines 167-200 (existing import/export methods)
- **Models.swift:** Lines 196-219 (ToastMessage, ToastType, ToastAction)
- **NWPathMonitor:** Apple Network.framework documentation

---

*Research complete — ready for planning*
