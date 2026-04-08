import SwiftUI
import ServiceManagement

// MARK: - SettingsView
// Application settings and preferences

struct SettingsView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @AppStorage("easytierPath") private var easytierPath = "/usr/local/bin"
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("logMaxEntries") private var logMaxEntries = 10000

    @State private var openAtLoginManager = OpenAtLoginManager()

    var body: some View {
        Form {
            Section("EasyTier") {
                LabeledContent("EasyTier 目录") {
                    HStack {
                        TextField("包含 easytier-core 和 easytier-cli 的目录", text: $easytierPath)
                            .disabled(vm.isAnyNetworkRunning)

                        Button("浏览...") {
                            showDirectoryPicker()
                        }
                        .disabled(vm.isAnyNetworkRunning)
                    }
                    .frame(width: 400)
                }

                if let detectedCore = detectedBinaryPath(named: "easytier-core") {
                    LabeledContent("检测到 easytier-core") {
                        Text(detectedCore)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let detectedCLI = detectedCLIPath() {
                    LabeledContent("检测到 easytier-cli") {
                        Text(detectedCLI)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                LabeledContent("版本") {
                    Text("未知")
                        .foregroundColor(.secondary)
                    // Could add detection via `easytier --version`
                }
            }

            Section("通用") {
                Toggle("开机启动 EasyTier", isOn: .init(
                    get: { startAtLogin },
                    set: { newValue in
                        startAtLogin = newValue
                        openAtLoginManager.setStartAtLogin(newValue)
                    }
                ))

                Toggle("显示菜单栏图标", isOn: $showMenuBar)

                Toggle("启动时自动连接", isOn: $autoConnectOnLaunch)
            }

            Section("日志") {
                Stepper("最大日志条数: \(logMaxEntries)",
                        value: $logMaxEntries,
                        in: 1000...100000,
                        step: 1000)

                Button("清空所有日志") {
                    vm.clearAllLogs()
                }
                .foregroundColor(.red)
            }

            Section("关于") {
                LabeledContent("应用程序") {
                    Text("EasyTier GUI")
                        .foregroundColor(.primary)
                }

                LabeledContent("版本") {
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                LabeledContent("EasyTier 项目") {
                    Link("github.com/EasyTier/EasyTier",
                         destination: URL(string: "https://github.com/EasyTier/EasyTier")!)
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(minWidth: 500, minHeight: 450)
    }

    // MARK: - File Picker

    private func showDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "请选择包含 easytier-core 和 easytier-cli 的目录"
        panel.directoryURL = URL(fileURLWithPath: easytierPath)

        if panel.runModal() == .OK, let url = panel.url {
            easytierPath = url.path
        }
    }

    private func detectedBinaryPath(named binaryName: String) -> String? {
        let directoryURL = URL(fileURLWithPath: easytierPath)
        let candidate = directoryURL.appendingPathComponent(binaryName).path
        return FileManager.default.isExecutableFile(atPath: candidate) ? candidate : nil
    }

    private func detectedCLIPath() -> String? {
        detectedBinaryPath(named: "easytier-cli") ?? detectedBinaryPath(named: "easytier-core-cli")
    }
}

// MARK: - Open At Login Manager

struct OpenAtLoginManager {
    private let bundleID = Bundle.main.bundleIdentifier ?? "cn.begitcn.EasyTierGUI"

    func setStartAtLogin(_ enabled: Bool) {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            // Use new API for macOS 13+
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
            // Use deprecated API for older macOS versions
            SMLoginItemSetEnabled(bundleID as CFString, enabled)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ProcessViewModel())
        .frame(width: 550, height: 500)
}
