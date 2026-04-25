---
wave: 1
depends_on: []
files_modified:
  - EasyTierGUI/Services/ConfigManager.swift
  - EasyTierGUI/Views/ConnectionView.swift
autonomous: true
requirements:
  - CONF-01  # Export single config
  - CONF-02  # Import config
  - CONF-03  # Export all configs
  - CONF-04  # Schema validation (existing)
  - CONF-05  # Conflict handling (overwrite)
  - CONF-06  # Sensitive data handling (exclude password option)
---

# Plan: Config Import/Export with Toast Feedback

**Phase:** 04-config-import-export-foundation
**Created:** 2026-04-25

## Overview

This plan addresses the gaps identified in Phase 4 context:
1. Add "Exclude password" option to export UI (D-02)
2. Replace Alert with Toast notifications for import/export feedback (D-13, D-14)
3. Ensure existing import/export methods work correctly with the new UI changes

The existing codebase already has:
- `ConfigManager.exportConfig()`, `importConfig()`, `exportAllConfigs()`, `importConfigsFromAnyFormat()`
- `ConnectionView` has import/export buttons and file panels
- Toast mechanism exists from Phase 1 (`ToastMessage`, `ToastType`, `ProcessViewModel.showToast`)

## must_haves

- [ ] Export UI shows "Exclude password" checkbox
- [ ] When checked, exported config has `networkPassword` set to empty string
- [ ] Import/export success/failure shown via Toast (not Alert)
- [ ] Toast messages match D-14: "已导出配置 {name}" / "已导入配置"
- [ ] All existing import/export functionality preserved

---

## Tasks

### Task 1: Add excludePassword option to ConfigManager export methods

<read_first>
- EasyTierGUI/Services/ConfigManager.swift (file to modify)
- EasyTierGUI/Models/Models.swift (EasyTierConfig structure with networkPassword field)
</read_first>

<acceptance_criteria>
- ConfigManager.swift contains `func exportConfig(_ config: EasyTierConfig, to url: URL, excludePassword: Bool) throws`
- ConfigManager.swift contains `func exportAllConfigs(to url: URL, excludePassword: Bool) throws`
- When `excludePassword=true`, exported JSON has `"networkPassword": ""`
- When `excludePassword=false` (default), exported JSON preserves original password
- Existing methods without `excludePassword` parameter remain for backward compatibility (defaulting to `false`)
</acceptance_criteria>

<action>
Modify `ConfigManager.swift` to add `excludePassword` parameter to export methods:

1. Add new method `exportConfig(_ config: EasyTierConfig, to url: URL, excludePassword: Bool) throws`:
   - If `excludePassword` is true, create a copy of config with `networkPassword = ""`
   - Encode and write to URL using existing encoder

2. Add new method `exportAllConfigs(to url: URL, excludePassword: Bool) throws`:
   - If `excludePassword` is true, map all configs to copies with `networkPassword = ""`
   - Encode and write to URL

3. Keep existing `exportConfig(_ config:to url:)` and `exportAllConfigs(to url:)` methods calling new methods with `excludePassword: false`

Example implementation:
```swift
/// 导出单个配置（可选排除密码）
func exportConfig(_ config: EasyTierConfig, to url: URL, excludePassword: Bool = false) throws {
    var exportConfig = config
    if excludePassword {
        exportConfig.networkPassword = ""
    }
    let data = try encoder.encode(exportConfig)
    try data.write(to: url)
}

/// 导出所有配置（可选排除密码）
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
```

</action>

---

### Task 2: Add export options UI with "Exclude password" checkbox

<read_first>
- EasyTierGUI/Views/ConnectionView.swift (file to modify - ConfigListSection struct)
- EasyTierGUI/Models/Models.swift (ToastType enum)
- EasyTierGUI/Services/ProcessViewModel.swift (showToast method)
</read_first>

<acceptance_criteria>
- ConnectionView.swift contains `@State private var excludePasswordOnExport: Bool = false`
- ConnectionView.swift contains `@State private var showExportOptions: Bool = false`
- Export single config button shows a menu/confirmation dialog with "Exclude password" toggle before saving
- Export all configs button shows same option
- When user clicks export, NSSavePanel appears with appropriate filename
- State variables are defined in `ConfigListSection` struct
</acceptance_criteria>

<action>
Modify `ConnectionView.swift` to add export options UI:

1. Add state variables to `ConfigListSection` struct (after line 246):
```swift
@State private var excludePasswordOnExport: Bool = false
@State private var showExportOptions: Bool = false
@State private var pendingExportConfig: EasyTierConfig?
@State private var pendingExportAll: Bool = false
```

2. Replace the single config export button (around line 397-407) with a Menu that shows export options:
```swift
Menu {
    Button {
        excludePasswordOnExport = false
        performExportConfig(config)
    } label: {
        Label("导出（包含密码）", systemImage: "key")
    }
    Button {
        excludePasswordOnExport = true
        performExportConfig(config)
    } label: {
        Label("导出（排除密码）", systemImage: "key.slash")
    }
} label: {
    Image(systemName: "arrow.up.doc")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .frame(width: 26, height: 26)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
}
.menuStyle(.borderlessButton)
.help("导出此配置")
```

3. Replace "Export All" button (around line 334-350) with a Menu:
```swift
Menu {
    Button {
        excludePasswordOnExport = false
        performExportAll()
    } label: {
        Label("导出全部（包含密码）", systemImage: "key")
    }
    Button {
        excludePasswordOnExport = true
        performExportAll()
    } label: {
        Label("导出全部（排除密码）", systemImage: "key.slash")
    }
} label: {
    HStack(spacing: 4) {
        Image(systemName: "square.and.arrow.up")
        Text("导出全部")
    }
    .font(.system(size: 11, weight: .medium))
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(Color.orange.opacity(0.1))
    .foregroundColor(.orange)
    .cornerRadius(6)
}
.menuStyle(.borderlessButton)
.disabled(vm.configManager.configs.isEmpty)
.opacity(vm.configManager.configs.isEmpty ? 0.5 : 1)
```

4. Add new helper methods `performExportConfig(_ config:)` and `performExportAll()` that:
   - Show NSSavePanel with appropriate filename
   - Call ConfigManager export with `excludePasswordOnExport` parameter
   - Show Toast on success/failure

</action>

---

### Task 3: Replace Alert with Toast for import/export feedback

<read_first>
- EasyTierGUI/Views/ConnectionView.swift (file to modify - import/export methods and alert modifiers)
- EasyTierGUI/Services/ProcessViewModel.swift (showToast method signature and ToastType enum)
- EasyTierGUI/Models/Models.swift (ToastType enum values: .error, .warning, .info)
</read_first>

<acceptance_criteria>
- ConnectionView.swift does NOT contain `@State private var showExportSuccess`
- ConnectionView.swift does NOT contain `@State private var showImportError`
- ConnectionView.swift does NOT contain `@State private var showExportAllSuccess`
- ConnectionView.swift does NOT contain `@State private var showImportSkipped`
- ConnectionView.swift does NOT contain `.alert("导出成功", isPresented: $showExportSuccess)`
- ConnectionView.swift does NOT contain `.alert("导入失败", isPresented: $showImportError)`
- `importConfig()` method calls `vm.showToast()` for success with text "已导入配置"
- `importConfig()` method calls `vm.showToast()` for failure with type `.error`
- `performExportConfig()` calls `vm.showToast("已导出配置 \(config.name)", type: .info)`
- `performExportAll()` calls `vm.showToast("已导出全部配置", type: .info)`
</acceptance_criteria>

<action>
Modify `ConnectionView.swift` to replace all Alert-based feedback with Toast:

1. Remove these state variables from `ConfigListSection`:
   - `@State private var showExportSuccess = false`
   - `@State private var showImportError = false`
   - `@State private var importErrorMessage = ""`
   - `@State private var showExportAllSuccess = false`
   - `@State private var showImportSkipped = false`
   - `@State private var skippedConfigNames: [String] = []`

2. Remove all `.alert()` modifiers from the view (lines 510-536)

3. Update `importConfig()` method to use Toast:
```swift
private func importConfig() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canCreateDirectories = false
    panel.allowedContentTypes = [.json]
    panel.title = "选择配置文件"
    panel.message = "选择要导入的 EasyTier 配置文件"

    if panel.runModal() == .OK, !panel.urls.isEmpty {
        var importedCount = 0
        var skippedCount = 0

        for url in panel.urls {
            do {
                let configs = try vm.configManager.importConfigsFromAnyFormat(from: url)
                for config in configs {
                    // Check for duplicates (per D-03: overwrite if same UUID or name)
                    let existingIndex = vm.configManager.configs.firstIndex { existing in
                        existing.id == config.id || existing.name == config.name
                    }
                    
                    if let index = existingIndex {
                        // D-03: Direct overwrite
                        vm.configManager.updateConfig(config, at: index)
                    } else {
                        vm.configManager.addConfig(config)
                    }
                    importedCount += 1
                }
            } catch {
                vm.showToast("导入失败：\(error.localizedDescription)", type: .error)
                return
            }
        }

        if importedCount > 0 {
            vm.showToast("已导入 \(importedCount) 个配置", type: .info)
        }
    }
}
```

4. Create `performExportConfig(_ config:)` method:
```swift
private func performExportConfig(_ config: EasyTierConfig) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.title = "保存配置文件"
    panel.message = "选择配置文件的保存位置"
    panel.nameFieldStringValue = "\(config.name).json"

    if panel.runModal() == .OK, let url = panel.url {
        do {
            try vm.configManager.exportConfig(config, to: url, excludePassword: excludePasswordOnExport)
            vm.showToast("已导出配置「\(config.name)」", type: .info)
        } catch {
            vm.showToast("导出失败：\(error.localizedDescription)", type: .error)
        }
    }
}
```

5. Create `performExportAll()` method:
```swift
private func performExportAll() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.json]
    panel.title = "导出所有配置"
    panel.message = "选择配置文件的保存位置"
    panel.nameFieldStringValue = "EasyTier_全部配置.json"

    if panel.runModal() == .OK, let url = panel.url {
        do {
            try vm.configManager.exportAllConfigs(to: url, excludePassword: excludePasswordOnExport)
            vm.showToast("已导出全部配置", type: .info)
        } catch {
            vm.showToast("导出失败：\(error.localizedDescription)", type: .error)
        }
    }
}
```

6. Remove the old `exportConfig(_ config:)` and `exportAllConfigs()` methods that used alerts

</action>

---

### Task 4: Update conflict handling to match D-03 (direct overwrite)

<read_first>
- EasyTierGUI/Views/ConnectionView.swift (file to modify - importConfig method)
- .planning/phases/04-config-import-export-foundation/04-CONTEXT.md (D-03: direct overwrite decision)
</read_first>

<acceptance_criteria>
- `importConfig()` method checks for duplicate by UUID OR name match
- When duplicate found, existing config is overwritten directly (no confirmation dialog)
- No "skip duplicate" logic remains
- Toast shows "已导入配置" or "已导入 X 个配置" on success
</acceptance_criteria>

<action>
The import conflict handling is updated in Task 3. Verify the implementation:

1. Duplicate detection checks both UUID and name:
```swift
let existingIndex = vm.configManager.configs.firstIndex { existing in
    existing.id == config.id || existing.name == config.name
}
```

2. When found, directly update (per D-03):
```swift
if let index = existingIndex {
    vm.configManager.updateConfig(config, at: index)
} else {
    vm.configManager.addConfig(config)
}
```

3. No "skip" logic or confirmation dialogs - this matches D-03 decision for direct overwrite

</action>

---

## Verification

After all tasks complete, verify:

1. **Build succeeds:** `./build.sh Debug` exits 0
2. **Export single config:** Click export menu → choose "导出（排除密码）" → save → exported JSON has `"networkPassword": ""`
3. **Export single config with password:** Click export menu → choose "导出（包含密码）" → save → exported JSON preserves password
4. **Export all configs:** Similar behavior for export all
5. **Import config:** Import JSON file → Toast shows "已导入配置" → config appears in list
6. **Import duplicate:** Import same file again → existing config overwritten, Toast shows "已导入配置"
7. **No Alert dialogs:** Verify `.alert()` modifiers removed from ConnectionView.swift
8. **Toast appears:** Toast notification appears in top-right corner and auto-dismisses after 3 seconds

---

## Dependencies

- Phase 1 Toast mechanism must be working (already shipped)
- ConfigManager import/export methods must exist (already implemented)
