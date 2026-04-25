//
//  SettingsView.swift
//  EasyTierGUI
//
//  应用设置和偏好
//

import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @StateObject private var binaryManager = BinaryManager.shared

    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("showDockIcon") private var showDockIcon = true
    @AppStorage("enableLogMonitoring") private var enableLogMonitoring = false

    @State private var openAtLoginManager = OpenAtLoginManager()
    @State private var showVisibilityAlert = false
    @State private var showResetConfirmation = false
    @State private var appear = false

    // MARK: - Backup State
    @State private var lastBackupDate: Date?
    private let backupService = BackupService()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Form {
                    // MARK: - EasyTier Section
                    Section(header: Text("EasyTier").font(.system(.subheadline, design: .rounded))) {
                        // 更新状态横幅
                        updateBannerSection

                        // 版本信息
                        versionInfoSection

                        // 更新操作按钮
                        updateActionSection
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                    // MARK: - 通用 Section
                    Section(header: Text("通用").font(.system(.subheadline, design: .rounded))) {
                        Toggle("开机启动 EasyTier", isOn: .init(
                            get: { startAtLogin },
                            set: { newValue in
                                startAtLogin = newValue
                                openAtLoginManager.setStartAtLogin(newValue)
                            }
                        ))

                        Toggle("显示系统托盘图标", isOn: .init(
                            get: { showMenuBar },
                            set: { newValue in
                                if !newValue && !showDockIcon {
                                    showVisibilityAlert = true
                                } else {
                                    showMenuBar = newValue
                                    MenuBarManager.shared.setVisible(newValue)
                                }
                            }
                        ))

                        Toggle("显示程序坞图标", isOn: .init(
                            get: { showDockIcon },
                            set: { newValue in
                                if !newValue && !showMenuBar {
                                    showVisibilityAlert = true
                                } else {
                                    showDockIcon = newValue
                                }
                            }
                        ))

                        Toggle("启动时自动连接", isOn: $autoConnectOnLaunch)
                        Toggle("启用日志监控（调试）", isOn: .init(
                            get: { enableLogMonitoring },
                            set: { newValue in
                                enableLogMonitoring = newValue
                                vm.setLogMonitoringEnabled(newValue)
                            }
                        ))
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

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

                    // MARK: - 关于 Section
                    Section(header: Text("关于").font(.system(.subheadline, design: .rounded))) {
                        LabeledContent("应用程序") {
                            Text("EasyTier GUI")
                                .foregroundColor(.primary)
                        }

                        LabeledContent("版本") {
                            Text("1.5")
                                .foregroundColor(.secondary)
                        }

                        LabeledContent("EasyTier 项目") {
                            Link("github.com/EasyTier/EasyTier",
                                 destination: URL(string: "https://github.com/EasyTier/EasyTier")!)
                        }
                    }
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            withAnimation(.standard.delay(0.1)) {
                appear = true
            }
            Task {
                await Task.yield()
                await binaryManager.refreshCurrentVersion()
            }
        }
        .alert("无法保存设置", isPresented: $showVisibilityAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("必须保留至少一个可见入口（系统托盘或程序坞），以确保您可以访问应用程序。")
        }
        .confirmationDialog(
            "确定要重置到内置版本吗？",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                resetToBundledVersion()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这将删除已安装的更新版本，回退到应用内置的版本。")
        }
    }

    // MARK: - Update Banner Section

    @ViewBuilder
    private var updateBannerSection: some View {
        switch binaryManager.updateState {
        case .updateAvailable(let version):
            UpdateBanner(
                version: version,
                onUpdate: { startUpdate() },
                onSkip: { binaryManager.skipCurrentVersion() }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        case .downloading(let progress):
            DownloadProgressBanner(progress: progress)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        case .installed:
            if let version = binaryManager.currentVersion {
                UpdateCompleteBanner(
                    version: version,
                    onDismiss: { binaryManager.resetUpdateState() }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

        case .error(let message):
            ErrorBanner(
                message: message,
                onRetry: { Task { await binaryManager.checkForUpdate(force: true) } },
                onDismiss: { binaryManager.resetUpdateState() }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        default:
            EmptyView()
        }
    }

    // MARK: - Version Info Section

    @ViewBuilder
    private var versionInfoSection: some View {
        // 当前版本
        LabeledContent("当前版本") {
            HStack(spacing: 6) {
                if let version = binaryManager.currentVersion {
                    Text("v\(version)")
                        .foregroundColor(.primary)

                    // 版本来源标签
                    let source = binaryManager.binarySource(for: .core)
                    Text(source == .installed ? "已安装" : "内置")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(source == .installed ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .foregroundColor(source == .installed ? .blue : .secondary)
                        .cornerRadius(4)
                } else {
                    Text("未安装")
                        .foregroundColor(.secondary)
                }
            }
        }

        // 最新版本
        if let latest = binaryManager.latestVersion {
            LabeledContent("最新版本") {
                Text(latest.displayVersion)
                    .foregroundColor(binaryManager.updateState.isUpdateAvailable ? .blue : .secondary)
            }
        }

    }

    // MARK: - Update Action Section

    @ViewBuilder
    private var updateActionSection: some View {
        HStack(spacing: 12) {
            // 检查更新按钮
            Button {
                Task {
                    await binaryManager.checkForUpdate(force: true)
                }
            } label: {
                if binaryManager.isCheckingForUpdate {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("检查更新")
                }
            }
            .disabled(binaryManager.isCheckingForUpdate || isUpdating)

            // 重置按钮（仅当有用户安装版本时显示）
            if binaryManager.binarySource(for: .core) == .installed {
                Button("重置到内置版本") {
                    showResetConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

    private var isUpdating: Bool {
        if case .downloading = binaryManager.updateState { return true }
        return false
    }

    private func startUpdate() {
        guard let version = binaryManager.latestVersion else { return }

        Task {
            do {
                try await binaryManager.downloadAndInstall(version: version)
            } catch {
                // 错误已在 BinaryManager 中处理
            }
        }
    }

    private func resetToBundledVersion() {
        do {
            try binaryManager.clearInstalledVersion()
        } catch {
            print("Failed to reset: \(error)")
        }
    }

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
            try backupService.exportBackup(to: url, configManager: vm.configManager)
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
}

// MARK: - Open At Login Manager

struct OpenAtLoginManager {
    private let bundleID = Bundle.main.bundleIdentifier ?? "cn.begitcn.EasyTierGUI"

    func setStartAtLogin(_ enabled: Bool) {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set login item: \(error)")
            }
        } else {
            SMLoginItemSetEnabled(bundleID as CFString, enabled)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ProcessViewModel())
        .frame(width: 550, height: 600)
}
