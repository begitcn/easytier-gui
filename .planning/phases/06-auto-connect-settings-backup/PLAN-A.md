---
wave: 1
depends_on: []
files_modified:
  - EasyTierGUI/Services/BackupService.swift
  - EasyTierGUI/Services/ProcessViewModel.swift
  - EasyTierGUI/Views/SettingsView.swift
autonomous: true
requirements:
  - AUTO-02
  - AUTO-05
  - SETT-01
  - SETT-02
  - SETT-03
---

# Phase 6 Plan A: Auto-Connect Enhancement & Settings Backup

**Created:** 2026-04-25
**Phase:** 06-auto-connect-settings-backup

---

## Overview

This plan implements:
1. **AUTO-02**: Remember last-used network configuration
2. **AUTO-05**: Toast notification with retry button on auto-connect failure
3. **SETT-01**: Backup all configs + AppStorage preferences to JSON
4. **SETT-02**: Restore from backup file
5. **SETT-03**: Direct overwrite mode for restore (per D-05 decision)

**AUTO-01** (toggle) and **AUTO-03** (login item) already exist in the codebase.

**AUTO-04** (network readiness) is handled in Plan B (EasyTierGUIApp.swift modifications).

> **Note on SETT-03**: The requirement specifies "conflict resolution options" but this is implemented per D-05 decision ("直接覆盖" - direct overwrite). This is intentional and locked from discuss-phase.

---

<threat_model>
## Security Threat Model

### Assets
- **Backup files**: JSON files containing network configurations and app preferences
- **UserDefaults data**: App preferences stored locally
- **Network configurations**: EasyTierConfig objects with network IDs and peer information

### Threats
1. **Malicious backup file**: An attacker could craft a backup JSON file with malicious configuration values
   - **Impact**: User loads malicious config, potentially connecting to attacker-controlled networks
   - **Likelihood**: Medium (requires user to manually open malicious file)

2. **Data tampering**: Backup files could be modified in transit or on disk
   - **Impact**: Corrupted or malicious configurations loaded
   - **Likelihood**: Low (local file access required)

3. **Credential exposure**: Backup files may contain sensitive network information (network IDs, peer addresses)
   - **Impact**: Network topology exposed if backup file is leaked
   - **Likelihood**: Low (user-controlled file location)

### Mitigations
1. **JSON validation**: BackupService validates JSON structure before applying; malformed JSON throws `BackupError.invalidFormat`
2. **File permissions**: Backup files use user-selected locations via NSSavePanel/NSOpenPanel; user controls access
3. **No sensitive data in backup**: EasyTierConfig does not store passwords or private keys; only network IDs and peer info
4. **No automatic backup loading**: User must explicitly select backup file via UI (no auto-restore on launch)
5. **UserDefaults key validation**: ApplyBackup only writes to known, hardcoded preference keys

### Residual Risks
- User may share backup file containing network topology information
- No integrity verification (checksum) on backup files (acceptable for local use)

</threat_model>

---

## Task 1: Create BackupService.swift

<read_first>
- EasyTierGUI/Models/Models.swift (EasyTierConfig structure for backup format)
- EasyTierGUI/Services/ConfigManager.swift (existing export/import patterns)
- EasyTierGUI/Views/SettingsView.swift (AppStorage keys to backup)
</read_first>

<action>
Create new file `EasyTierGUI/Services/BackupService.swift` with:

1. **BackupData struct** (Codable):
   - `version: String` = "1.0"
   - `timestamp: Date`
   - `configs: [EasyTierConfig]`
   - `preferences: PreferencesBackup`

2. **PreferencesBackup struct** (Codable):
   - `startAtLogin: Bool`
   - `showMenuBar: Bool`
   - `autoConnectOnLaunch: Bool`
   - `showDockIcon: Bool`
   - `enableLogMonitoring: Bool`
   - `lastConnectedConfigId: String?`

3. **BackupService class** with methods:
   - `createBackupData() -> BackupData` - gathers all configs and preferences from UserDefaults
   - `exportBackup(to url: URL) throws` - encodes BackupData to JSON and writes to URL
   - `importBackup(from url: URL) throws -> BackupData` - decodes BackupData from URL
   - `applyBackup(_ backup: BackupData, configManager: ConfigManager)` - replaces all configs and preferences

4. **BackupError enum** (LocalizedError):
   - `case invalidFormat`
   - `case fileNotFound`

5. **Apply backup logic** (per D-05 direct overwrite):
   - Set `configManager.configs = backup.configs`
   - Write each preference to UserDefaults using exact keys: "startAtLogin", "showMenuBar", "autoConnectOnLaunch", "showDockIcon", "enableLogMonitoring", "lastConnectedConfigId"

Use JSONEncoder with `.prettyPrinted` and `.sortedKeys` formatting (same as ConfigManager).
</action>

<acceptance_criteria>
- File `EasyTierGUI/Services/BackupService.swift` exists
- File contains `struct BackupData: Codable` with fields: version, timestamp, configs, preferences
- File contains `struct PreferencesBackup: Codable` with 6 fields
- File contains `class BackupService`
- File contains `func exportBackup(to url: URL) throws`
- File contains `func importBackup(from url: URL) throws -> BackupData`
- File contains `func applyBackup(_ backup: BackupData, configManager: ConfigManager)`
- JSONEncoder uses `.prettyPrinted` and `.sortedKeys`
- File compiles without errors
</acceptance_criteria>

---

## Task 2: Track Last Connected Config in ProcessViewModel

<read_first>
- EasyTierGUI/Services/ProcessViewModel.swift (existing connect logic)
- EasyTierGUI/Models/Models.swift (ToastMessage, ToastAction)
</read_first>

<action>
Modify `EasyTierGUI/Services/ProcessViewModel.swift`:

1. **After successful connection in `connect(configID:)` method** (around line 449, after `await runtime.connect(config: config)`):
   Add code to save the last connected config ID to UserDefaults:
   ```swift
   // Save last connected config ID for auto-connect
   if runtime.status == .connected {
       UserDefaults.standard.set(configID.uuidString, forKey: "lastConnectedConfigId")
   }
   ```

2. **Add new method `connectLastUsed()`** after the `connectAll()` method:
   ```swift
   /// Connect to the last used configuration
   func connectLastUsed() async -> Bool {
       guard let configIdString = UserDefaults.standard.string(forKey: "lastConnectedConfigId"),
             let configId = UUID(uuidString: configIdString),
             configsContains(id: configId) else {
           return false
       }
       await connect(configID: configId)
       return true
   }

   private func configsContains(id: UUID) -> Bool {
       configManager.configs.contains { $0.id == id }
   }
   ```

3. **Add `lastConnectedConfigId` computed property** for UI access:
   ```swift
   var lastConnectedConfigId: UUID? {
       guard let string = UserDefaults.standard.string(forKey: "lastConnectedConfigId"),
             let uuid = UUID(uuidString: string) else { return nil }
       return uuid
   }

   var lastConnectedConfigName: String? {
       guard let id = lastConnectedConfigId else { return nil }
       return configManager.configs.first(where: { $0.id == id })?.name
   }
   ```
</action>

<acceptance_criteria>
- ProcessViewModel.swift contains `UserDefaults.standard.set(configID.uuidString, forKey: "lastConnectedConfigId")` in connect method
- ProcessViewModel.swift contains `func connectLastUsed() async -> Bool`
- ProcessViewModel.swift contains `var lastConnectedConfigId: UUID?`
- ProcessViewModel.swift contains `var lastConnectedConfigName: String?`
- File compiles without errors
</acceptance_criteria>

---

## Task 3: Add Backup/Restore UI in SettingsView

<read_first>
- EasyTierGUI/Views/SettingsView.swift (existing structure and AppStorage pattern)
- EasyTierGUI/Services/BackupService.swift (created in Task 1)
- EasyTierGUI/Services/ProcessViewModel.swift (toast method)
</read_first>

<action>
Modify `EasyTierGUI/Views/SettingsView.swift`:

1. **Add import** at top of file:
   ```swift
   import UniformTypeIdentifiers
   ```

2. **Add State properties** in SettingsView:
   ```swift
   @State private var lastBackupDate: Date?
   private let backupService = BackupService()
   ```

3. **Add new Section** after the "通用" Section (after line ~89, before "关于" Section):
   ```swift
   // MARK: - 备份与恢复 Section
   Section(header: Text("备份与恢复").font(.system(.subheadline, design: .rounded))) {
       HStack(spacing: 12) {
           Button("备份设置") {
               performBackup()
           }

           Button("恢复设置") {
               performRestore()
           }
       }

       if let lastBackupDate = lastBackupDate {
           LabeledContent("上次备份") {
               Text(lastBackupDate, style: .date)
                   .foregroundColor(.secondary)
           }
       }
   }
   .opacity(appear ? 1 : 0)
   .offset(y: appear ? 0 : 10)
   ```

4. **Add helper methods** at bottom of SettingsView, before `#Preview`:
   ```swift
   // MARK: - Backup Actions

   private func performBackup() {
       let panel = NSSavePanel()
       panel.allowedContentTypes = [UTType.json]
       let dateFormatter = DateFormatter()
       dateFormatter.dateFormat = "yyyy-MM-dd"
       panel.nameFieldStringValue = "EasyTierGUI-Backup-\(dateFormatter.string(from: Date())).json"
       panel.canCreateDirectories = true

       guard panel.runModal() == .OK, let url = panel.url else { return }

       do {
           try backupService.exportBackup(to: url)
           lastBackupDate = Date()
           vm.showToast("备份成功", type: .info)
       } catch {
           vm.showToast("备份失败: \(error.localizedDescription)", type: .error)
       }
   }

   private func performRestore() {
       let panel = NSOpenPanel()
       panel.allowedContentTypes = [UTType.json]
       panel.allowsMultipleSelection = false
       panel.message = "恢复将覆盖所有现有配置和偏好设置"

       guard panel.runModal() == .OK, let url = panel.url else { return }

       do {
           let backup = try backupService.importBackup(from: url)
           backupService.applyBackup(backup, configManager: vm.configManager)
           vm.showToast("恢复成功", type: .info)
       } catch {
           vm.showToast("恢复失败: \(error.localizedDescription)", type: .error)
       }
   }
   ```
</action>

<acceptance_criteria>
- SettingsView.swift contains `import UniformTypeIdentifiers`
- SettingsView.swift contains `@State private var lastBackupDate: Date?`
- SettingsView.swift contains `private let backupService = BackupService()`
- SettingsView.swift contains Section with header "备份与恢复"
- SettingsView.swift contains `Button("备份设置")` and `Button("恢复设置")`
- SettingsView.swift contains `func performBackup()`
- SettingsView.swift contains `func performRestore()`
- Backup panel uses `UTType.json` and name format `EasyTierGUI-Backup-{date}.json`
- Restore panel shows message about overwriting
- File compiles without errors
</acceptance_criteria>

---

## Verification

After all tasks complete, verify:

1. **BackupService compiles**:
   ```bash
   xcodebuild -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug build 2>&1 | grep -i error || echo "Build succeeded"
   ```

2. **Backup file format** (manual test):
   - Create backup, open JSON file
   - Verify it contains `version: "1.0"`, `timestamp`, `configs` array, `preferences` object
   - Verify preferences has all 6 keys including `lastConnectedConfigId`

3. **Last connected tracking** (manual test):
   - Connect to a network config
   - Check `UserDefaults.standard.string(forKey: "lastConnectedConfigId")` returns valid UUID
   - Verify `lastConnectedConfigName` returns correct name

4. **Toast on failure** (verified in Plan B auto-connect test)

---

## Requirements Traceability

| Requirement | Task(s) |
|-------------|---------|
| AUTO-02 | Task 2 |
| AUTO-05 | Task 2 + Plan B |
| SETT-01 | Task 1, Task 3 |
| SETT-02 | Task 1, Task 3 |
| SETT-03 | Task 1 (applyBackup direct overwrite) |

---

*Plan created: 2026-04-25*
