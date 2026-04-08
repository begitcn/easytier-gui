import SwiftUI

// MARK: - ConnectionView
// View for managing EasyTier connection and network configuration

struct ConnectionView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var editingConfig: EasyTierConfig?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connection Status Card
                StatusCard()
                    .environmentObject(vm)

                // Configuration Section
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
                }

                // Config List Section
                ConfigListSection()
                    .environmentObject(vm)
            }
            .padding(32)
            .frame(maxWidth: 600)
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

struct StatusCard: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(vm.selectedStatus.color.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: vm.selectedStatus == .connected ? "checkmark.circle.fill" :
                        vm.selectedStatus == .connecting ? "arrow.clockwise.circle.fill" :
                        vm.selectedStatus == .error ? "xmark.circle.fill" :
                        "network.slash")
                    .font(.system(size: 36))
                    .foregroundColor(vm.selectedStatus.color)
            }

            Text(vm.selectedStatus.description)
                .font(.title2)
                .fontWeight(.semibold)

            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }

            // Connect/Disconnect button
            Button(action: toggleConnection) {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(width: 20, height: 20)
                } else {
                    Label((vm.activeConfig.map(vm.isRunning) ?? false) ? "断开连接" : "连接",
                          systemImage: (vm.activeConfig.map(vm.isRunning) ?? false) ? "wifi.slash" : "wifi")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint((vm.activeConfig.map(vm.isRunning) ?? false) ? .red : .blue)
            .disabled(isConnecting || vm.activeConfig == nil)
            .task(id: vm.selectedStatus) {
                isConnecting = false
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func toggleConnection() {
        Task {
            isConnecting = true
            if let activeConfig = vm.activeConfig, vm.isRunning(activeConfig) {
                await vm.disconnect()
            } else {
                await vm.connect()
            }
            isConnecting = false
        }
    }
}

// MARK: - Config Form View

struct ConfigFormView: View {
    @State var config: EasyTierConfig
    @EnvironmentObject var vm: ProcessViewModel
    var onSave: (EasyTierConfig) -> Void

    var body: some View {
        GroupBox("配置") {
            Form {
                Section(header: Text("基础设置")) {
                    TextField("配置名称", text: $config.name)
                    TextField("网络名称", text: $config.networkName)
                    SecureField("网络密码", text: $config.networkPassword)
                    TextField("服务器地址 (留空则作为服务器节点)", text: $config.serverURI)
                }

                Section(header: Text("高级设置")) {
                    TextField("主机名 (留空使用系统主机名)", text: $config.hostname)

                    Toggle("开启延迟优先模式", isOn: $config.enableLatencyFirst)
                    Toggle("启用私有模式", isOn: $config.enablePrivateMode)
                    Toggle("接受 DNS 配置", isOn: $config.enableMagicDNS)
                    Toggle("启用多线程", isOn: $config.enableMultiThread)
                    Toggle("启用KCP代理", isOn: $config.enableKCP)
                }

                Section(header: Text("TUN 设备")) {
                    Toggle("使用 DHCP", isOn: $config.useDHCP)

                    if !config.useDHCP {
                        TextField("IPv4 地址/掩码 (例如: 192.168.55.13/24)", text: $config.tunConfig.ipv4)
                            .disabled(config.useDHCP)
                    }

                    TextField("子网掩码", text: $config.tunConfig.netmask)
                        .disabled(true)
                    Stepper("MTU: \(config.tunConfig.mtu)", value: $config.tunConfig.mtu, in: 576...9000)
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

                Section(header: Text("节点")) {
                    PeerListEditor(peers: $config.peers)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal)
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
    }
}

// MARK: - Peer List Editor

struct PeerListEditor: View {
    @Binding var peers: [String]
    @State private var newPeer = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(peers.indices, id: \.self) { index in
                HStack {
                    Text(peers[index])
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Button(action: { peers.remove(at: index) }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("输入节点地址", text: $newPeer)
                    .onSubmit { addPeer() }
                Button("添加") { addPeer() }
                    .disabled(newPeer.isEmpty)
            }
        }
    }

    private func addPeer() {
        let trimmed = newPeer.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        peers.append(trimmed)
        newPeer = ""
    }
}

// MARK: - Config List Section

struct ConfigListSection: View {
    @EnvironmentObject var vm: ProcessViewModel

    var body: some View {
        GroupBox("虚拟网络") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(vm.configManager.configs.indices, id: \.self) { index in
                    let config = vm.configManager.configs[index]
                    let isRunning = vm.isRunning(config)
                    HStack {
                        Button(action: {
                            vm.configManager.setActiveConfig(at: index)
                        }) {
                            HStack {
                                Image(systemName: vm.configManager.activeConfigIndex == index ?
                                      "checkmark.circle.fill" : "circle")
                                    .foregroundColor(vm.configManager.activeConfigIndex == index ? .blue : .secondary)
                                Text(config.name)
                                if vm.configManager.activeConfigIndex == index {
                                    Text("(当前)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if isRunning {
                                    Text("(运行中)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button(isRunning ? "断开" : "连接") {
                            Task {
                                if isRunning {
                                    await vm.disconnect(configID: config.id)
                                } else {
                                    await vm.connect(configID: config.id)
                                }
                            }
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            vm.configManager.deleteConfig(at: index)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunning || vm.configManager.configs.count <= 1)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }

        Button("添加虚拟网络", systemImage: "plus") {
            vm.addNewConfig()
        }
        .buttonStyle(.bordered)
    }
}

// MARK: - Preview

#Preview {
    ConnectionView()
        .environmentObject(ProcessViewModel())
        .frame(width: 600, height: 800)
}
