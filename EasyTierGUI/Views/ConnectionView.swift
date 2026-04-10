import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - ConnectionView
// View for managing EasyTier connection and network configuration

struct ConnectionView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var editingConfig: EasyTierConfig?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Config List Section (Top)
                ConfigListSection()
                    .environmentObject(vm)

                // Configuration Section (Bottom)
                if let config = vm.configManager.activeConfig {
                    ConfigFormView(config: config) { updatedConfig in
                        let index = vm.configManager.activeConfigIndex
                        vm.configManager.updateConfig(updatedConfig, at: index)
                    }
                    .id(config.id)
                    .environmentObject(vm)
                } else {
                    Text("暂无可用配置")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding(32)
            .frame(maxWidth: 880)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let config = vm.configManager.activeConfig {
                editingConfig = config
            }
        }
    }
}

// MARK: - Status Card


// MARK: - Config Form View

struct ConfigFormView: View {
    @State var config: EasyTierConfig
    @EnvironmentObject var vm: ProcessViewModel
    var onSave: (EasyTierConfig) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("配置设置")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                Spacer()
                Text("* 为必填项")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 4)
            }

            HStack(alignment: .top, spacing: 16) {
                // Left Column
                Form {
                    Section(header: Text("基础设置").font(.system(.subheadline, design: .rounded))) {
                        requiredField(label: "配置名称", text: $config.name)
                        requiredField(label: "网络名称", text: $config.networkName)
                        requiredSecureField(label: "网络密码", text: $config.networkPassword)
                        requiredField(label: "服务器地址", text: $config.serverURI)
                    }

                    Section(header: Text("TUN 设备").font(.system(.subheadline, design: .rounded))) {
                        Toggle("使用 DHCP", isOn: $config.useDHCP)

                        if !config.useDHCP {
                            TextField("IPv4 地址/掩码 (例如: 192.168.55.13/24)", text: $config.tunConfig.ipv4)
                                .disabled(config.useDHCP)
                        }

                        TextField("子网掩码", text: $config.tunConfig.netmask)
                            .disabled(true)
                        Stepper("MTU: \(config.tunConfig.mtu)", value: $config.tunConfig.mtu, in: 576...9000)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)

                // Right Column
                Form {
                    Section(header: Text("高级设置")) {
                        TextField("主机名", text: $config.hostname)
                            .onAppear {
                                if config.hostname.isEmpty {
                                    config.hostname = ProcessInfo.processInfo.hostName
                                }
                            }

                        Toggle("开启延迟优先模式", isOn: $config.enableLatencyFirst)
                        Toggle("启用私有模式", isOn: $config.enablePrivateMode)
                        Toggle("接受 DNS 配置", isOn: $config.enableMagicDNS)
                        Toggle("启用多线程", isOn: $config.enableMultiThread)
                        Toggle("启用KCP代理", isOn: $config.enableKCP)
                    }

                    Section(header: Text("其他选项")) {
                        Stepper("监听端口: \(config.listenPort)", value: $config.listenPort, in: 1...65535)
                        Stepper("管理端口: \(config.rpcPortalPort)", value: $config.rpcPortalPort, in: 1...65535)
                        Picker("日志级别", selection: $config.logLevel) {
                            Text("调试").tag("debug")
                            Text("信息").tag("info")
                            Text("警告").tag("warn")
                            Text("错误").tag("error")
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(minHeight: 380)
            .disabled(vm.activeConfig.map(vm.isRunning) ?? false)
            .onChange(of: config) { _, newValue in
                onSave(newValue)
            }
            .onChange(of: vm.configManager.activeConfig?.id) { _, _ in
                if let activeConfig = vm.configManager.activeConfig {
                    config = activeConfig
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func requiredField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(.primary)
                .layoutPriority(1)
            Text("*")
                .foregroundColor(.red)
                .fontWeight(.bold)
            Spacer()
            TextField("", text: text)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func requiredSecureField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(.primary)
                .layoutPriority(1)
            Text("*")
                .foregroundColor(.red)
                .fontWeight(.bold)
            Spacer()
            SecureField("", text: text)
                .multilineTextAlignment(.trailing)
        }
    }
}



// MARK: - Config List Section

struct ConfigListSection: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showExportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showExportAllSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("虚拟网络")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)

                Spacer()

                // 导入导出按钮
                HStack(spacing: 8) {
                    Button(action: { importConfig() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)

                    Button(action: { exportAllConfigs() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出全部")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                    .disabled(vm.configManager.configs.isEmpty)
                    .opacity(vm.configManager.configs.isEmpty ? 0.5 : 1)
                }
            }

            VStack(spacing: 12) {
                ForEach(vm.configManager.configs.indices, id: \.self) { index in
                    let config = vm.configManager.configs[index]
                    let isRunning = vm.isRunning(config)
                    let isActive = vm.configManager.activeConfigIndex == index

                    HStack(spacing: 16) {
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(isActive ? .accentColor : .secondary.opacity(0.5))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(config.name)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(isActive ? .bold : .regular)

                                if isRunning {
                                    Text("运行中")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(config.networkName.isEmpty ? "未命名网络" : config.networkName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 单个配置的导出按钮
                        Button(action: { exportConfig(config) }) {
                            Image(systemName: "arrow.up.doc")
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .help("导出此配置")

                        Button(isRunning ? "断开" : "连接") {
                            if isRunning {
                                Task { await vm.disconnect(configID: config.id) }
                            } else {
                                // Validate required fields
                                if let msg = validateConfig(config) {
                                    validationMessage = msg
                                    showValidationAlert = true
                                } else {
                                    Task { await vm.connect(configID: config.id) }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isRunning ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        .foregroundColor(isRunning ? .red : .blue)
                        .cornerRadius(8)

                        Button(action: {
                            withAnimation {
                                vm.configManager.deleteConfig(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunning || vm.configManager.configs.count <= 1)
                        .opacity((isRunning || vm.configManager.configs.count <= 1) ? 0.3 : 1)
                    }
                    .padding(16)
                    .background(isActive ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            vm.configManager.setActiveConfig(at: index)
                        }
                    }
                }
            }

            Button(action: {
                withAnimation {
                    vm.addNewConfig()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加虚拟网络")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .alert("必填项未完成", isPresented: $showValidationAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .alert("导出成功", isPresented: $showExportSuccess) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("配置已成功导出")
        }
        .alert("导入失败", isPresented: $showImportError) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .alert("导出成功", isPresented: $showExportAllSuccess) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("所有配置已成功导出")
        }
    }

    // MARK: - Import/Export Methods

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.json]
        panel.title = "选择配置文件"
        panel.message = "选择要导入的 EasyTier 配置文件"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let config = try vm.configManager.importConfig(from: url)
                // 检查是否已存在相同 ID 的配置
                if vm.configManager.configs.contains(where: { $0.id == config.id }) {
                    // 生成新的 ID 避免冲突
                    var newConfig = config
                    newConfig.id = UUID()
                    vm.configManager.addConfig(newConfig)
                } else {
                    vm.configManager.addConfig(config)
                }
            } catch {
                importErrorMessage = "无法读取配置文件：\(error.localizedDescription)"
                showImportError = true
            }
        }
    }

    private func exportConfig(_ config: EasyTierConfig) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.title = "保存配置文件"
        panel.message = "选择配置文件的保存位置"
        panel.nameFieldStringValue = "\(config.name).json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try vm.configManager.exportConfig(config, to: url)
                showExportSuccess = true
            } catch {
                importErrorMessage = "导出失败：\(error.localizedDescription)"
                showImportError = true
            }
        }
    }

    private func exportAllConfigs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.title = "导出所有配置"
        panel.message = "选择配置文件的保存位置"
        panel.nameFieldStringValue = "EasyTier_全部配置.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try vm.configManager.exportAllConfigs(to: url)
                showExportAllSuccess = true
            } catch {
                importErrorMessage = "导出失败：\(error.localizedDescription)"
                showImportError = true
            }
        }
    }

    private func validateConfig(_ config: EasyTierConfig) -> String? {
        var missing: [String] = []
        if config.name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("配置名称") }
        if config.networkName.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("网络名称") }
        if config.networkPassword.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("网络密码") }
        if config.serverURI.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("服务器地址") }
        guard !missing.isEmpty else { return nil }
        return "以下必填项不能为空：\n" + missing.map { "• \($0)" }.joined(separator: "\n")
    }
}

// MARK: - Preview

#Preview {
    ConnectionView()
        .environmentObject(ProcessViewModel())
        .frame(width: 600, height: 800)
}
