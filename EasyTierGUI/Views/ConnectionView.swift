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
            VStack(spacing: 20) {
                // Config List Section (Top)
                ConfigListSection()
                    .environmentObject(vm)

                // Configuration Section (Bottom)
                if let config = vm.configManager.activeConfig {
                    ConfigFormView(config: config) { updatedConfig in
                        let index = vm.activeConfigIndex
                        vm.configManager.updateConfig(updatedConfig, at: index)
                    }
                    .id(config.id)
                    .environmentObject(vm)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("暂无可用配置")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(CGFloat.spacingXL)
            .frame(maxWidth: 920)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
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
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.spacingM) {
            HStack {
                Text("配置设置")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("* 为必填项")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.red.opacity(0.7))
            }
            .padding(.horizontal, 4)

            HStack(alignment: .top, spacing: 20) {
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
                            TextField("IPv4 地址", text: $config.tunConfig.ipv4)
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
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(minHeight: 360)
            .disabled(vm.activeConfig.map(vm.isRunning) ?? false)
            .onChange(of: config) { _, newValue in
                scheduleSave(for: newValue)
            }
            .onChange(of: vm.configManager.activeConfig?.id) { _, _ in
                if let activeConfig = vm.configManager.activeConfig {
                    saveTask?.cancel()
                    config = activeConfig
                }
            }
        }
        .padding(CGFloat.cardPadding)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        .onDisappear {
            saveTask?.cancel()
        }
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

    private func scheduleSave(for value: EasyTierConfig) {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            onSave(value)
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
    @State private var isConnectingAll = false
    @State private var isDisconnectingAll = false
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("虚拟网络")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)

                Spacer()

                // 批量操作按钮
                HStack(spacing: 6) {
                    Button(action: {
                        isConnectingAll = true
                        Task {
                            await connectAll()
                            isConnectingAll = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isConnectingAll {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: isConnectingAll ? "" : "link")
                            Text(isConnectingAll ? "连接中..." : "全部连接")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                    .disabled(vm.configManager.configs.isEmpty || vm.isAnyNetworkRunning || isConnectingAll)
                    .opacity((vm.configManager.configs.isEmpty || vm.isAnyNetworkRunning || isConnectingAll) ? 0.5 : 1)

                    Button(action: {
                        isDisconnectingAll = true
                        Task {
                            await disconnectAll()
                            isDisconnectingAll = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isDisconnectingAll {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Image(systemName: isDisconnectingAll ? "" : "link.circle")
                            Text(isDisconnectingAll ? "断开中..." : "全部断开")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                    .disabled(!vm.isAnyNetworkRunning || isDisconnectingAll)
                    .opacity((!vm.isAnyNetworkRunning || isDisconnectingAll) ? 0.5 : 1)
                }

                // 导入导出按钮
                HStack(spacing: 6) {
                    Button(action: { importConfig() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                            Text("导入")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)

                    Button(action: { exportAllConfigs() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("导出全部")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                    .disabled(vm.configManager.configs.isEmpty)
                    .opacity(vm.configManager.configs.isEmpty ? 0.5 : 1)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(vm.configManager.configs.indices, id: \.self) { index in
                    let config = vm.configManager.configs[index]
                    let isRunning = vm.isRunning(config)
                    let isActive = vm.activeConfigIndex == index
                    let status = vm.status(for: config)
                    let runtimeError = vm.errorMessage(for: config)
                    let isConnectingNow = vm.isConnecting(config)
                    let isDisconnectingNow = vm.isDisconnecting(config)
                    let isOperating = vm.isOperating(config)

                    HStack(spacing: 14) {
                        // Selection indicator
                        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isActive ? .accentColor : .secondary.opacity(0.4))

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(config.name)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(isActive ? .semibold : .regular)

                                statusBadge(for: status)
                            }

                            Text(config.networkName.isEmpty ? "未命名网络" : config.networkName)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)

                            if let runtimeError, !runtimeError.isEmpty {
                                Label(runtimeError, systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.red.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        // Action buttons
                        HStack(spacing: 6) {
                            // Export button
                            Button(action: { exportConfig(config) }) {
                                Image(systemName: "arrow.up.doc")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 26, height: 26)
                                    .background(Color.secondary.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("导出此配置")

                            // Connect/Disconnect button
                            Button(action: {
                                if isRunning {
                                    Task { await vm.disconnect(configID: config.id) }
                                } else {
                                    // Validate required fields
                                    if let msg = validateConfig(config) {
                                        validationMessage = msg
                                        showValidationAlert = true
                                    } else {
                                        Task { await connect(config) }
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if isOperating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isConnectingNow ? "连接中..." : (isDisconnectingNow ? "断开中..." : (isRunning ? "断开" : "连接")))
                                }
                                .font(.system(size: 12, weight: .medium))
                                .frame(minWidth: 60)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isRunning ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.12))
                            .foregroundColor(isRunning ? .red : .accentColor)
                            .cornerRadius(6)
                            .disabled(isOperating)
                            .opacity(isOperating ? 0.6 : 1)

                            // Delete button
                            Button(action: {
                                withAnimation {
                                    vm.configManager.deleteConfig(at: index)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.7))
                                    .frame(width: 26, height: 26)
                                    .background(Color.red.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(isRunning || isOperating || vm.configManager.configs.count <= 1)
                            .opacity((isRunning || isOperating || vm.configManager.configs.count <= 1) ? 0.3 : 1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(isActive ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.4))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.configManager.setActiveConfig(at: index)
                        }
                    }
                }
            }

            // Add button
            Button(action: {
                withAnimation {
                    vm.addNewConfig()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("添加虚拟网络")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(CGFloat.cardPadding)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
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

    // MARK: - Batch Operations

    private func connectAll() {
        Task {
            for config in vm.configManager.configs {
                if !vm.isRunning(config) && validateConfig(config) == nil {
                    await connect(config)
                }
            }
        }
    }

    private func disconnectAll() {
        Task {
            for config in vm.configManager.configs {
                if vm.isRunning(config) {
                    await vm.disconnect(configID: config.id)
                }
            }
        }
    }

    private func connect(_ config: EasyTierConfig) async {
        await vm.connect(configID: config.id)
        guard let error = vm.errorMessage(for: config), !error.isEmpty else {
            return
        }
        vm.showToast("「\(config.name)」连接失败：\(error)", type: .error)
    }

    // MARK: - Status Badge Helpers

    private func statusIcon(for status: NetworkStatus) -> String {
        switch status {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }

    private func statusColor(for status: NetworkStatus) -> Color {
        switch status {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .secondary
        case .error: return .red
        }
    }

    private func statusText(for status: NetworkStatus) -> String {
        switch status {
        case .connected: return "运行中"
        case .connecting: return "连接中"
        case .disconnected: return ""
        case .error: return "连接失败"
        }
    }

    @ViewBuilder
    private func statusBadge(for status: NetworkStatus) -> some View {
        switch status {
        case .connected:
            HStack(spacing: 4) {
                Image(systemName: statusIcon(for: status))
                    .font(.system(size: 8))
                Text(statusText(for: status))
            }
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .clipShape(Capsule())
        case .connecting:
            HStack(spacing: 4) {
                Image(systemName: statusIcon(for: status))
                    .font(.system(size: 8))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                Text(statusText(for: status))
            }
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .clipShape(Capsule())
            .onAppear { isAnimating = true }
            .onDisappear { isAnimating = false }
        case .error:
            HStack(spacing: 4) {
                Image(systemName: statusIcon(for: status))
                    .font(.system(size: 8))
                Text(statusText(for: status))
            }
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.15))
            .foregroundColor(statusColor(for: status))
            .clipShape(Capsule())
        case .disconnected:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    ConnectionView()
        .environmentObject(ProcessViewModel())
        .frame(width: 600, height: 800)
}
