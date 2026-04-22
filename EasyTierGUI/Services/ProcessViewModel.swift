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
                guard let self = self else { return }
                if self.peers != newPeers {
                    self.peers = newPeers
                    self.onStateChange?()
                }
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
    @Published private(set) var activeConfigIndex: Int = -1

    // MARK: - Dependencies

    let configManager = ConfigManager()
    private var runtimes: [UUID: NetworkRuntime] = [:]

    private var cancellables = Set<AnyCancellable>()
    private var dailyUpdateCheckTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        activeConfigIndex = configManager.activeConfigIndex
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
            .sink { [weak self] index in
                self?.activeConfigIndex = index
            }
            .store(in: &cancellables)

        startDailyUpdateCheckScheduler()
    }

    deinit {
        dailyUpdateCheckTask?.cancel()
    }

    // MARK: - Core Detection

    /// 检测 easytier-core 是否存在
    var easytierCoreExists: Bool {
        BinaryManager.shared.binaryExists(for: .core)
    }

    // MARK: - Binary Update Check Scheduler

    private func startDailyUpdateCheckScheduler() {
        dailyUpdateCheckTask?.cancel()
        dailyUpdateCheckTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let sleepNanoseconds = self.nanosecondsUntilNextCheck(hour: 14, minute: 0)
                try? await Task.sleep(nanoseconds: sleepNanoseconds)
                guard !Task.isCancelled else { break }
                await BinaryManager.shared.checkForUpdate()
            }
        }
    }

    private func nanosecondsUntilNextCheck(hour: Int, minute: Int) -> UInt64 {
        let calendar = Calendar.current
        let now = Date()

        guard var nextCheck = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) else {
            return 60 * 1_000_000_000
        }

        if nextCheck <= now {
            nextCheck = calendar.date(byAdding: .day, value: 1, to: nextCheck) ?? now.addingTimeInterval(24 * 3600)
        }

        let interval = max(1, nextCheck.timeIntervalSince(now))
        return UInt64(interval * 1_000_000_000)
    }

    // MARK: - Active Config/Runtime

    var activeConfig: EasyTierConfig? {
        configManager.activeConfig
    }

    var activeRuntime: NetworkRuntime? {
        guard let config = activeConfig else { return nil }
        return runtimeIfExists(for: config.id)
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
        runtimeIfExists(for: config.id)?.status ?? .disconnected
    }

    func errorMessage(for config: EasyTierConfig) -> String? {
        runtimeIfExists(for: config.id)?.errorMessage
    }

    func isRunning(_ config: EasyTierConfig) -> Bool {
        runtimeIfExists(for: config.id)?.service.isRunning ?? false
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
        let runtime = ensureRuntime(for: configID)

        // 检查内核是否存在
        guard easytierCoreExists else {
            runtime.errorMessage = "未找到 easytier-core，请在设置中配置正确的 EasyTier 目录。"
            runtime.status = .error
            refreshOverallStatus()
            return
        }

        // 检查端口冲突
        let listenConflict = configManager.configs.first {
            $0.id != config.id && isRunning($0) && $0.listenPort == config.listenPort
        }
        let rpcConflict = configManager.configs.first {
            $0.id != config.id && isRunning($0) && $0.rpcPortalPort == config.rpcPortalPort
        }

        if listenConflict != nil || rpcConflict != nil {
            var conflictDetails: [String] = []
            if let listenConflict {
                conflictDetails.append("监听端口 \(config.listenPort) 与「\(listenConflict.name)」冲突")
            }
            if let rpcConflict {
                conflictDetails.append("管理端口 \(config.rpcPortalPort) 与「\(rpcConflict.name)」冲突")
            }
            runtime.errorMessage = "无法连接：端口冲突。\n" + conflictDetails.joined(separator: "\n")
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

    func clearAllLogs() {
        for runtime in runtimes.values {
            runtime.clearLogs()
        }
    }

    func setLogMonitoringEnabled(_ enabled: Bool) {
        for runtime in runtimes.values {
            runtime.service.setLogMonitoringEnabled(enabled)
        }
    }

    func forceStopAllSync(allowPrivilegePrompt: Bool = true) {
        for runtime in runtimes.values {
            runtime.service.forceStop(allowPrivilegePrompt: allowPrivilegePrompt)
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

    private func runtimeIfExists(for id: UUID) -> NetworkRuntime? {
        runtimes[id]
    }

    private func ensureRuntime(for id: UUID) -> NetworkRuntime {
        runtime(for: id)
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
