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
    @AppStorage("showDockIcon") private var showDockIcon = true
    @AppStorage("logMaxEntries") private var logMaxEntries = 10000

    @State private var openAtLoginManager = OpenAtLoginManager()
    @State private var detectedCoreVersion: String = "检测中..."
    @State private var showVisibilityAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Text("设置首选项")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                Form {
                    Section(header: Text("EasyTier").font(.system(.subheadline, design: .rounded))) {
                        LabeledContent("EasyTier 目录") {
                            HStack {
                                TextField("", text: $easytierPath)
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
                            Text(detectedCoreVersion)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }

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
                    }

                    Section(header: Text("日志").font(.system(.subheadline, design: .rounded))) {
                        Stepper("最大日志条数: \(logMaxEntries)",
                                value: $logMaxEntries,
                                in: 1000...100000,
                                step: 1000)

                        Button("清空所有日志") {
                            vm.clearAllLogs()
                        }
                        .foregroundColor(.red)
                    }

                    Section(header: Text("关于").font(.system(.subheadline, design: .rounded))) {
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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 15, y: 5)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            detectCoreVersion()
        }
        .onChange(of: easytierPath) { _, _ in
            detectCoreVersion()
        }
        .alert("无法保存设置", isPresented: $showVisibilityAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("必须保留至少一个可见入口（系统托盘或程序坞），以确保您可以访问应用程序。")
        }
    }

    private func detectCoreVersion() {
        let corePath: String
        if let path = detectedBinaryPath(named: "easytier-core") {
            corePath = path
        } else {
            detectedCoreVersion = "未找到 easytier-core"
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: corePath)
            task.arguments = ["-V"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = (String(data: data, encoding: .utf8) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async {
                    detectedCoreVersion = output.isEmpty ? "未知" : output
                }
            } catch {
                DispatchQueue.main.async {
                    detectedCoreVersion = "检测失败"
                }
            }
        }
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