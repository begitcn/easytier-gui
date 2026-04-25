# Phase 6: Auto-Connect & Settings Backup - Plan Summary

**Created:** 2026-04-25
**Phase:** 06-auto-connect-settings-backup

---

## Requirements Coverage

| ID | Requirement | Status | Plan |
|----|-------------|--------|------|
| AUTO-01 | Toggle auto-connect on startup | ✅ Existing | N/A |
| AUTO-02 | Remember last-used config | 🆕 New | PLAN-A Task 2 |
| AUTO-03 | Launch at login when auto-connect enabled | ✅ Existing | N/A |
| AUTO-04 | Network readiness check before connecting | 🆕 New | PLAN-B Task 1 |
| AUTO-05 | Notification on auto-connect failure | 🆕 New | PLAN-A Task 2, PLAN-B Task 1 |
| SETT-01 | Backup all configs + preferences | 🆕 New | PLAN-A Task 1, Task 3 |
| SETT-02 | Restore from backup file | 🆕 New | PLAN-A Task 1, Task 3 |
| SETT-03 | Conflict resolution options | 🆕 New | PLAN-A Task 1 (direct overwrite per D-05) |

**Coverage:** 8/8 requirements (5 new implementations, 3 existing features)

---

## Execution Order

```
Wave 1: PLAN-A (BackupService, ProcessViewModel, SettingsView)
    ↓
Wave 2: PLAN-B (EasyTierGUIApp - depends on ProcessViewModel.connectLastUsed)
```

---

## Files Modified

| File | Action | Plan |
|------|--------|------|
| `EasyTierGUI/Services/BackupService.swift` | **Create** | PLAN-A Task 1 |
| `EasyTierGUI/Services/ProcessViewModel.swift` | **Modify** | PLAN-A Task 2 |
| `EasyTierGUI/Views/SettingsView.swift` | **Modify** | PLAN-A Task 3 |
| `EasyTierGUI/EasyTierGUIApp.swift` | **Modify** | PLAN-B Task 1 |

---

## Key Decisions Applied

From `06-CONTEXT.md`:

| Decision | Implementation |
|----------|----------------|
| D-01: Remember last-used single config | `lastConnectedConfigId` in UserDefaults |
| D-02: Network readiness + 30s timeout | `NWPathMonitor` in EasyTierGUIApp |
| D-03: Toast notification + retry | `ToastAction` with retry handler |
| D-04: Backup includes configs + preferences | `BackupData` struct with both |
| D-05: Direct overwrite on restore | `applyBackup()` replaces all without merge |
| D-06: Keep existing SMAppService | No changes to OpenAtLoginManager |

---

## must_haves (Goal-Backward Verification)

Before marking phase complete, verify:

1. ✅ User can backup all configs and preferences to JSON file
2. ✅ Backup file contains: version, timestamp, configs array, preferences object
3. ✅ User can restore from backup file
4. ✅ Restore replaces all existing configs and preferences (no merge)
5. ✅ App remembers last connected config UUID after successful connection
6. ✅ Auto-connect on launch connects only the last-used config (not all)
7. ✅ Auto-connect waits for network readiness with 30s timeout
8. ✅ Auto-connect shows Toast with retry button on network timeout
9. ✅ Existing features unchanged: auto-connect toggle, login item

---

## Build Verification

```bash
# Build the project
./build.sh Debug

# Or with xcodebuild directly:
xcodebuild -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug build
```

---

*Plans created: 2026-04-25*
*Ready for execution*
