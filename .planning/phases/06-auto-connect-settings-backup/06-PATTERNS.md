# Phase 6 Patterns: Auto-Connect & Settings Backup

**Phase:** 06-auto-connect-settings-backup
**Generated:** 2026-04-25

---

## Files to Create/Modify

| File | Action | Role |
|------|--------|------|
| `EasyTierGUI/Services/BackupService.swift` | **Create** | Backup/restore logic |
| `EasyTierGUI/EasyTierGUIApp.swift` | **Modify** | Auto-connect logic with network readiness |
| `EasyTierGUI/Services/ProcessViewModel.swift` | **Modify** | Add lastConnectedConfigId tracking |
| `EasyTierGUI/Views/SettingsView.swift` | **Modify** | Add backup/restore UI |

---

## Pattern Analysis

### 1. AppStorage Pattern (SettingsView.swift)

**Role:** User preferences persistence
**Data Flow:** UserDefaults → @AppStorage → SwiftUI View Binding

```swift
// Existing pattern (SettingsView.swift:17-21)
@AppStorage("startAtLogin") private var startAtLogin = false
@AppStorage("showMenuBar") private var showMenuBar = true
@AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
@AppStorage("showDockIcon") private var showDockIcon = true
@AppStorage("enableLogMonitoring") private var enableLogMonitoring = false

// Toggle binding pattern (SettingsView.swift:48-54)
Toggle("开机启动 EasyTier", isOn: .init(
    get: { startAtLogin },
    set: { newValue in
        startAtLogin = newValue
        openAtLoginManager.setStartAtLogin(newValue)
    }
))
```

**Pattern for Phase 6:** Add `@AppStorage("lastConnectedConfigId")` to track last connected config.

---

### 2. Auto-Connect Logic (EasyTierGUIApp.swift)

**Role:** App lifecycle, launch-time auto-connect
**Data Flow:** NSApplication.didFinishLaunching → UserDefaults check → connectAll()

```swift
// Existing pattern (EasyTierGUIApp.swift:72-82)
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

**Pattern for Phase 6:**
1. Read `lastConnectedConfigId` from UserDefaults
2. Implement network readiness check with NWPathMonitor (30s timeout)
3. Connect only the last-used config
4. Show Toast on failure with retry action

---

### 3. Toast Notification (Models.swift + ProcessViewModel.swift)

**Role:** User notifications with action buttons
**Data Flow:** Error/Event → ToastMessage → ToastView

```swift
// Toast definitions (Models.swift:199-219)
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: ToastType
    var action: ToastAction?
}

enum ToastType {
    case error
    case warning
    case info
}

struct ToastAction {
    let title: String
    let handler: () -> Void
}
```

```swift
// Toast display in ProcessViewModel (ProcessViewModel.swift:206-222)
@Published var toastMessage: ToastMessage?

func showToast(_ text: String, type: ToastType = .error, action: ToastAction? = nil) {
    toastMessage = ToastMessage(text: text, type: type, action: action)

    // Auto-dismiss after 3 seconds
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        if toastMessage?.text == text {
            toastMessage = nil
        }
    }
}

// Usage with retry action (ProcessViewModel.swift:453-458)
showToast(error, type: .error, action: ToastAction(title: "重试") { [weak self] in
    guard let self = self else { return }
    Task { await self.connect(configID: configID) }
})
```

**Pattern for Phase 6:** Use for AUTO-05 notification on auto-connect failure.

---

### 4. Config Import/Export (ConfigManager.swift)

**Role:** Config persistence and file I/O
**Data Flow:** ConfigManager ↔ JSON files in Application Support

```swift
// Export all configs (ConfigManager.swift:184-194)
func exportAllConfigs(to url: URL, excludePassword: Bool = false) throws {
    let exportConfigs = excludePassword
        ? configs.map { config -> EasyTierConfig in
            var c = config
            c.networkPassword = ""
            return c
        }
        : configs
    let data = try encoder.encode(exportConfigs)
    try data.write(to: url)
}

// Import from any format (ConfigManager.swift:203-218)
func importConfigsFromAnyFormat(from url: URL) throws -> [EasyTierConfig] {
    let data = try Data(contentsOf: url)

    // Try array format first (export all)
    if let configs = try? decoder.decode([EasyTierConfig].self, from: data) {
        return configs
    }

    // Then try single config format
    if let config = try? decoder.decode(EasyTierConfig.self, from: data) {
        return [config]
    }

    throw ConfigError.invalidFormat
}
```

**Pattern for Phase 6:** Reuse for backup file format (configs + preferences).

---

### 5. ProcessViewModel Connection Methods (ProcessViewModel.swift)

**Role:** Connection lifecycle management
**Data Flow:** View → connect(configID:) → NetworkRuntime → EasyTierService

```swift
// Connect single config (ProcessViewModel.swift:409-459)
func connect(configID: UUID) async {
    guard let config = configManager.configs.first(where: { $0.id == configID }) else { return }
    let runtime = ensureRuntime(for: configID)

    // Check for existing operation
    if runtime.isConnecting || runtime.isDisconnecting { return }

    // Check core exists
    guard easytierCoreExists else {
        runtime.errorMessage = "未找到 easytier-core"
        runtime.status = .error
        showToast("未找到 easytier-core", type: .error)
        refreshOverallStatus()
        return
    }

    // Check port conflicts
    // ... (port conflict logic)

    await runtime.connect(config: config)
    refreshOverallStatus()

    // Show toast with retry for authorization errors
    if runtime.status == .error, let error = runtime.errorMessage, error.contains("授权") || error.contains("权限") {
        showToast(error, type: .error, action: ToastAction(title: "重试") { [weak self] in
            guard let self = self else { return }
            Task { await self.connect(configID: configID) }
        })
    }
}

// Connect all configs (ProcessViewModel.swift:379-390)
func connectAll() async {
    for (index, config) in configManager.configs.enumerated() {
        if index > 0 {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds delay
        }
        await connect(configID: config.id)
    }
}
```

**Pattern for Phase 6:**
- Add `connectLastUsed()` method to connect only the last-used config
- Track successful connections to update `lastConnectedConfigId`

---

### 6. File Panel Integration (NSSavePanel/NSOpenPanel)

**Role:** File picker for backup/restore
**Data Flow:** SwiftUI View → NSSavePanel/NSOpenPanel → URL

```swift
// Note: Standard pattern for macOS file dialogs
// Used in Phase 4 import/export

// Example save panel (typical usage):
let panel = NSSavePanel()
panel.allowedContentTypes = [.json]
panel.nameFieldStringValue = "EasyTierGUI-Backup-\(dateString).json"
panel.canCreateDirectories = true

if panel.runModal() == .OK, let url = panel.url {
    // Save backup
}

// Example open panel:
let panel = NSOpenPanel()
panel.allowedContentTypes = [.json]
panel.allowsMultipleSelection = false

if panel.runModal() == .OK, let url = panel.url {
    // Load backup
}
```

---

## New Service Pattern: BackupService

### Role
Handle backup/restore operations for configs + preferences.

### Data Flow
```
Backup: ConfigManager.configs + AppStorage → BackupService → JSON file (NSSavePanel)
Restore: JSON file (NSOpenPanel) → BackupService → ConfigManager + UserDefaults
```

### Interface Design (BackupService.swift)

```swift
class BackupService {

    // MARK: - Backup Data Structure
    struct BackupData: Codable {
        let version: String
        let timestamp: Date
        let configs: [EasyTierConfig]
        let preferences: PreferencesBackup
    }

    struct PreferencesBackup: Codable {
        let startAtLogin: Bool
        let showMenuBar: Bool
        let autoConnectOnLaunch: Bool
        let showDockIcon: Bool
        let enableLogMonitoring: Bool
    }

    // MARK: - Methods

    /// Create backup data from current state
    func createBackupData() -> BackupData {
        BackupData(
            version: "1.0",
            timestamp: Date(),
            configs: configManager.configs,
            preferences: PreferencesBackup(
                startAtLogin: UserDefaults.standard.bool(forKey: "startAtLogin"),
                showMenuBar: UserDefaults.standard.bool(forKey: "showMenuBar"),
                autoConnectOnLaunch: UserDefaults.standard.bool(forKey: "autoConnectOnLaunch"),
                showDockIcon: UserDefaults.standard.bool(forKey: "showDockIcon"),
                enableLogMonitoring: UserDefaults.standard.bool(forKey: "enableLogMonitoring")
            )
        )
    }

    /// Export backup to URL
    func exportBackup(to url: URL) throws {
        let data = try JSONEncoder().encode(createBackupData())
        try data.write(to: url)
    }

    /// Import backup from URL and apply (direct overwrite per D-05)
    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let backup = try JSONDecoder().decode(BackupData.self, from: data)

        // Disconnect all before restore
        await processVM.disconnectAll()

        // Replace all configs (direct overwrite)
        configManager.configs = backup.configs

        // Replace preferences
        let prefs = backup.preferences
        UserDefaults.standard.set(prefs.startAtLogin, forKey: "startAtLogin")
        UserDefaults.standard.set(prefs.showMenuBar, forKey: "showMenuBar")
        UserDefaults.standard.set(prefs.autoConnectOnLaunch, forKey: "autoConnectOnLaunch")
        UserDefaults.standard.set(prefs.showDockIcon, forKey: "showDockIcon")
        UserDefaults.standard.set(prefs.enableLogMonitoring, forKey: "enableLogMonitoring")
    }
}
```

---

## Modified Files Detail

### EasyTierGUIApp.swift - Modified Auto-Connect Logic

**Add after line 82:**

```swift
// Modified auto-connect logic with network readiness check
.onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
    let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
    let lastConfigId = UserDefaults.standard.string(forKey: "lastConnectedConfigId")

    if autoConnect, let configIdString = lastConfigId,
       let configId = UUID(uuidString: configIdString) {
        Task {
            // Wait for network ready with 30s timeout
            let networkReady = await waitForNetworkReady(timeout: 30)

            // Short delay to let the UI settle
            try? await Task.sleep(nanoseconds: 800_000_000)

            // Connect last used config
            await processVM.connect(configID: configId)
        }
    }
}
```

**Add network monitor helper:**

```swift
// Network readiness check using NWPathMonitor
func waitForNetworkReady(timeout: TimeInterval) async -> Bool {
    await withCheckedContinuation { continuation in
        let monitor = NWPathMonitor()
        let startTime = Date()

        monitor.pathUpdateHandler = { path in
            if path.status == .satisfied {
                monitor.cancel()
                continuation.resume(returning: true)
            }
        }

        monitor.start(queue: DispatchQueue.global())

        // Timeout fallback
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            monitor.cancel()
            continuation.resume(returning: false)
        }
    }
}
```

---

### ProcessViewModel.swift - Track Last Connected Config

**Add to connection success handling:**

```swift
// After successful connection in connect(configID:)
if runtime.status == .connected {
    // Save last connected config ID
    UserDefaults.standard.set(configID.uuidString, forKey: "lastConnectedConfigId")
}
```

**Add new method:**

```swift
func connectLastUsed() async {
    guard let configIdString = UserDefaults.standard.string(forKey: "lastConnectedConfigId"),
          let configId = UUID(uuidString: configIdString),
          configManager.configs.contains(where: { $0.id == configId }) else {
        return
    }
    await connect(configID: configId)
}
```

---

### SettingsView.swift - Add Backup/Restore UI

**Add import:**

```swift
import UniformTypeIdentifiers
```

**Add new section after existing sections:**

```swift
// MARK: - Backup Section
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
```

**Add helper methods:**

```swift
@State private var lastBackupDate: Date?
private let backupService = BackupService()

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

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
        try backupService.importBackup(from: url)
        vm.showToast("恢复成功，请重启应用以使部分更改生效", type: .info)
    } catch {
        vm.showToast("恢复失败: \(error.localizedDescription)", type: .error)
    }
}
```

---

## Dependencies

| Dependency | Source | Usage |
|------------|--------|-------|
| NWPathMonitor | Network.framework (system) | Network readiness check |
| NSSavePanel/NSOpenPanel | AppKit (system) | File picker UI |
| Toast mechanism | Phase 1 (existing) | Error notifications |
| ConfigManager | Existing (Phase 4) | Config import/export |
| SMAppService | ServiceManagement (system) | Login items (no change needed) |

---

## Key Decisions from Context

1. **Direct overwrite mode** (D-05): Restore replaces all configs and preferences without merge options
2. **NWPathMonitor** for network readiness: 30-second timeout fallback
3. **Backup file format**: JSON with `version`, `timestamp`, `configs`, `preferences` fields
4. **Backup file naming**: `EasyTierGUI-Backup-{date}.json`
5. **Toast + retry** for auto-connect failures (AUTO-05)

---

*Patterns extracted from codebase analysis - ready for implementation*
