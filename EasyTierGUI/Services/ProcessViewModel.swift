//
//  ProcessViewModel.swift
//  EasyTierGUI
//
//  主 ViewModel - 管理网络配置和运行时状态
//

import Foundation
import Combine
import SwiftUI

// MARK: - Network Runtime

/// 单个网络的运行时状态
@MainActor
final class NetworkRuntime: ObservableObject, Identifiable {
    let id: UUID
    let service = EasyTierService()

    @Published var status: NetworkStatus = .disconnected
    @Published var errorMessage: String?
    @Published var peers: [PeerInfo] = []

    var onStateChange: (() -> Void)?

    private let rpcPortalProvider: () -> Int?
    private var peerTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(id: UUID, rpcPortalProvider: @escaping () -> Int?) {
        self.id = id
        self.rpcPortalProvider = rpcPortalProvider

        // 监听服务状态变化
        service.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                guard let self = self else { return }
                if isRunning {
                    self.status = .connected
                    self.startPeerPolling()
                } else {
                    self.status = .disconnected
                    self.stopPeerPolling()
                    self.peers.removeAll()
                }
                self.onStateChange?()
            }
            .store(in: &cancellables)
    }

    deinit {
        peerTimer?.invalidate()
        peerTimer = nil
        cancellables.removeAll()
    }

    // MARK: - Connection Control

    func connect(config: EasyTierConfig) async {
        status = .connecting
        errorMessage = nil
        onStateChange?()

        do {
            try await service.start(config: config)
        } catch {
            errorMessage = error.localizedDescription
            status = .error
            onStateChange?()
        }
    }

    func disconnect() async {
        do {
            try await service.stop()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            status = .error
            onStateChange?()
        }
    }

    func clearLogs() {
        service.clearLogs()
    }

    // MARK: - Peer Polling

    private func startPeerPolling() {
        peerTimer?.invalidate()
        peerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchPeers()
            }
        }
        fetchPeers()
    }

    private func stopPeerPolling() {
        peerTimer?.invalidate()
        peerTimer = nil
    }

    private func fetchPeers() {
        guard let port = currentRPCPortalPort else {
            peers = []
            return
        }

        service.fetchPeers(rpcPortalPort: port) { [weak self] newPeers in
            DispatchQueue.main.async {
                self?.peers = newPeers
                self?.onStateChange?()
            }
        }
    }

    private var currentRPCPortalPort: Int? {
        rpcPortalProvider()
    }
}

// MARK: - Process ViewModel

/// 主 ViewModel - 协调多网络配置和运行时
@MainActor
class ProcessViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var status: NetworkStatus = .disconnected
    @Published var selectedTab: AppTab = .connection

    // MARK: - Dependencies

    let configManager = ConfigManager()
    @Published private(set) var runtimes: [UUID: NetworkRuntime] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let kLastUpdateCheck = "easytierLastUpdateCheck"

    // MARK: - Initialization

    init() {
        syncRuntimes(with: configManager.configs)

        // 监听配置变化
        configManager.$configs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configs in
                self?.syncRuntimes(with: configs)
                self?.refreshOverallStatus()
            }
            .store(in: &cancellables)

        configManager.$activeConfigIndex
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // 后台检查 EasyTier 核心版本更新
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 延迟 3 秒
            await checkForBinaryUpdate()
        }
    }

    // MARK: - Core Detection

    /// 检测 easytier-core 是否存在
    var easytierCoreExists: Bool {
        BinaryManager.shared.binaryExists(for: .core)
    }

    // MARK: - Binary Update Check

    private func checkForBinaryUpdate() async {
        if let lastCheck = UserDefaults.standard.object(forKey: kLastUpdateCheck) as? Date {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < 86400 { // 24h 节流，避免频繁请求远端
                return
            }
        }
        await BinaryManager.shared.checkForUpdate()
    }

    // MARK: - Active Config/Runtime

    var activeConfig: EasyTierConfig? {
        configManager.activeConfig
    }

    var activeRuntime: NetworkRuntime? {
        guard let config = activeConfig else { return nil }
        return runtime(for: config.id)
    }

    var peers: [PeerInfo] {
        activeRuntime?.peers ?? []
    }

    var errorMessage: String? {
        activeRuntime?.errorMessage
    }

    var selectedStatus: NetworkStatus {
        activeRuntime?.status ?? .disconnected
    }

    var isAnyNetworkRunning: Bool {
        runtimes.values.contains(where: { $0.service.isRunning })
    }

    // MARK: - Status Helpers

    func status(for config: EasyTierConfig) -> NetworkStatus {
        runtime(for: config.id).status
    }

    func errorMessage(for config: EasyTierConfig) -> String? {
        runtime(for: config.id).errorMessage
    }

    func isRunning(_ config: EasyTierConfig) -> Bool {
        runtime(for: config.id).service.isRunning
    }

    // MARK: - Connection Control

    func connect() async {
        guard let config = activeConfig else { return }
        await connect(configID: config.id)
    }

    func disconnect() async {
        guard let config = activeConfig else { return }
        await disconnect(configID: config.id)
    }

    func connectAll() async {
        // Connect all networks sequentially to avoid race conditions
        for config in configManager.configs {
            await connect(configID: config.id)
        }
    }

    func disconnectAll() async {
        // Disconnect all networks in parallel
        await withTaskGroup(of: Void.self) { group in
            for runtime in runtimes.values {
                group.addTask {
                    await runtime.disconnect()
                }
            }
        }
        refreshOverallStatus()
    }

    func connect(configID: UUID) async {
        guard let config = configManager.configs.first(where: { $0.id == configID }) else { return }
        let runtime = runtime(for: configID)

        // 检查内核是否存在
        guard easytierCoreExists else {
            runtime.errorMessage = "未找到 easytier-core，请在设置中配置正确的 EasyTier 目录。"
            runtime.status = .error
            refreshOverallStatus()
            return
        }

        // 检查端口冲突
        let conflictingNetwork = configManager.configs.first {
            $0.id != config.id && isRunning($0) &&
            ($0.listenPort == config.listenPort || $0.rpcPortalPort == config.rpcPortalPort)
        }

        if let conflict = conflictingNetwork {
            runtime.errorMessage = "端口冲突：\"\(conflict.name)\" 与当前网络使用了相同的监听端口或管理端口。"
            runtime.status = .error
            refreshOverallStatus()
            return
        }

        await runtime.connect(config: config)
        refreshOverallStatus()
    }

    func disconnect(configID: UUID) async {
        guard let runtime = runtimes[configID] else { return }
        await runtime.disconnect()
        refreshOverallStatus()
    }

    func toggleConnection() async {
        guard let config = activeConfig else { return }
        if isRunning(config) {
            await disconnect(configID: config.id)
        } else {
            await connect(configID: config.id)
        }
    }

    // MARK: - Log Management

    func clearActiveLogs() {
        activeRuntime?.clearLogs()
    }

    func forceStopAllSync() {
        for runtime in runtimes.values {
            runtime.service.forceStop()
        }
    }

    // MARK: - Config Management

    func addNewConfig() {
        let name = generateUniqueNetworkName()
        let config = EasyTierConfig(name: name)
        configManager.addConfig(config)
    }

    /// 生成唯一的网络名称，避免与现有配置重复
    private func generateUniqueNetworkName() -> String {
        // 收集所有以"网络 "开头的现有名称中的编号
        let existingNumbers = configManager.configs.compactMap { config -> Int? in
            guard config.name.hasPrefix("网络 ") else { return nil }
            let suffix = String(config.name.dropFirst(3))
            return Int(suffix)
        }

        // 如果没有现有编号，从1开始
        if existingNumbers.isEmpty {
            return "网络 1"
        }

        // 找到第一个未被使用的编号
        let usedNumbers = Set(existingNumbers)
        var number = 1
        while usedNumbers.contains(number) {
            number += 1
        }

        return "网络 \(number)"
    }

    func deleteConfig(at index: Int) {
        let config = configManager.configs[index]
        guard !isRunning(config) else { return }
        configManager.deleteConfig(at: index)
    }

    // MARK: - Private Methods

    private func runtime(for id: UUID) -> NetworkRuntime {
        if let existing = runtimes[id] {
            return existing
        }

        let runtime = NetworkRuntime(id: id) { [weak self] in
            self?.configManager.configs.first(where: { $0.id == id })?.rpcPortalPort
        }
        runtime.onStateChange = { [weak self] in
            Task { @MainActor in
                self?.refreshOverallStatus()
            }
        }
        runtimes[id] = runtime
        return runtime
    }

    private func syncRuntimes(with configs: [EasyTierConfig]) {
        let validIDs = Set(configs.map(\.id))

        for config in configs where runtimes[config.id] == nil {
            _ = runtime(for: config.id)
        }

        for id in runtimes.keys where !validIDs.contains(id) {
            runtimes.removeValue(forKey: id)
        }
    }

    private func refreshOverallStatus() {
        let statuses = runtimes.values.map(\.status)
        let detailedStatuses = configManager.configs.map { (name: $0.name, status: status(for: $0)) }

        if statuses.contains(.error) {
            status = .error
        } else if statuses.contains(.connecting) {
            status = .connecting
        } else if statuses.contains(.connected) {
            status = .connected
        } else {
            status = .disconnected
        }

        MenuBarManager.shared.updateStatus(status, networkStatuses: detailedStatuses)
    }
}

// MARK: - App Tab

/// 应用标签页
enum AppTab: String, CaseIterable, Identifiable {
    case connection, peers, logs, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .connection: return "连接"
        case .peers: return "节点"
        case .logs: return "日志"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .connection: return "network"
        case .peers: return "rectangle.3.group"
        case .logs: return "doc.text"
        case .settings: return "gearshape"
        }
    }
}
