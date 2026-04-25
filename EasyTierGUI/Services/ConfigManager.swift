//
//  ConfigManager.swift
//  EasyTierGUI
//
//  配置管理器 - 处理网络配置的持久化
//

import Foundation
import Combine

// MARK: - Config Error

enum ConfigError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "配置文件格式无效"
        }
    }
}

// MARK: - Config Manager

/// 配置管理器 - 管理网络配置的增删改查和持久化
class ConfigManager: ObservableObject {

    // MARK: - Published Properties

    @Published var configs: [EasyTierConfig] = []
    @Published var activeConfigIndex: Int = -1

    // MARK: - Private Properties

    private let configsDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let persistenceQueue = DispatchQueue(label: "EasyTierGUI.ConfigPersistence", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5

    // MARK: - Initialization

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        configsDirectory = appSupport.appendingPathComponent("EasyTierGUI", isDirectory: true)

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        createConfigsDirectoryIfNeeded()
        loadConfigs()
    }

    private func createConfigsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: configsDirectory.path) {
            try? FileManager.default.createDirectory(at: configsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - CRUD Operations

    /// 添加新配置
    func addConfig(_ config: EasyTierConfig) {
        var config = config
        config.listenPort = normalizedListenPort(for: config)
        config.rpcPortalPort = normalizedRPCPortalPort(for: config)
        configs.append(config)
        activeConfigIndex = configs.count - 1
        saveConfigs()
    }

    /// 更新配置
    func updateConfig(_ config: EasyTierConfig, at index: Int) {
        guard index >= 0, index < configs.count else { return }
        configs[index] = config
        saveConfigs()
    }

    /// 删除配置
    func deleteConfig(at index: Int) {
        guard index >= 0, index < configs.count else { return }
        configs.remove(at: index)

        if activeConfigIndex == index {
            activeConfigIndex = configs.isEmpty ? -1 : 0
        } else if activeConfigIndex > index {
            activeConfigIndex -= 1
        }

        saveConfigs()
    }

    /// 设置当前活动配置
    func setActiveConfig(at index: Int) {
        guard index >= 0, index < configs.count else { return }
        activeConfigIndex = index
        saveConfigs()
    }

    /// 当前活动配置
    var activeConfig: EasyTierConfig? {
        get {
            guard activeConfigIndex >= 0, activeConfigIndex < configs.count else { return nil }
            return configs[activeConfigIndex]
        }
        set {
            guard let newValue = newValue, activeConfigIndex >= 0 else { return }
            configs[activeConfigIndex] = newValue
            saveConfigs()
        }
    }

    // MARK: - Persistence

    private func saveConfigs() {
        let configsSnapshot = configs
        let activeIndexSnapshot = activeConfigIndex
        let directory = configsDirectory

        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            var configEncoder = JSONEncoder()
            configEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            if let data = try? configEncoder.encode(configsSnapshot) {
                try? data.write(
                    to: directory.appendingPathComponent("configs.json"),
                    options: .atomic
                )
            }

            if let indexData = try? JSONEncoder().encode(activeIndexSnapshot) {
                try? indexData.write(
                    to: directory.appendingPathComponent("active_index.json"),
                    options: .atomic
                )
            }
        }
        pendingSaveWorkItem = workItem
        persistenceQueue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    private func loadConfigs() {
        let url = configsDirectory.appendingPathComponent("configs.json")
        if let data = try? Data(contentsOf: url),
           let loaded = try? decoder.decode([EasyTierConfig].self, from: data) {
            configs = loaded
        } else {
            configs = [EasyTierConfig(name: "Default")]
        }

        normalizeConfigs()

        let indexURL = configsDirectory.appendingPathComponent("active_index.json")
        if let data = try? Data(contentsOf: indexURL),
           let index = try? JSONDecoder().decode(Int.self, from: data),
           index < configs.count {
            activeConfigIndex = index
        } else if !configs.isEmpty {
            activeConfigIndex = 0
        }
    }

    // MARK: - Import/Export

    /// 导出单个配置
    func exportConfig(_ config: EasyTierConfig, to url: URL) throws {
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    /// 导入配置
    func importConfig(from url: URL) throws -> EasyTierConfig {
        let data = try Data(contentsOf: url)
        return try decoder.decode(EasyTierConfig.self, from: data)
    }

    /// 导出所有配置
    func exportAllConfigs(to url: URL) throws {
        let data = try encoder.encode(configs)
        try data.write(to: url)
    }

    /// 导入多个配置
    func importConfigs(from url: URL) throws -> [EasyTierConfig] {
        let data = try Data(contentsOf: url)
        return try decoder.decode([EasyTierConfig].self, from: data)
    }

    /// 导入配置（自动检测单个或多个格式）
    func importConfigsFromAnyFormat(from url: URL) throws -> [EasyTierConfig] {
        let data = try Data(contentsOf: url)

        // 先尝试解析为数组格式（导出全部）
        if let configs = try? decoder.decode([EasyTierConfig].self, from: data) {
            return configs
        }

        // 再尝试解析为单个配置格式
        if let config = try? decoder.decode(EasyTierConfig.self, from: data) {
            return [config]
        }

        // 都失败了，抛出错误
        throw ConfigError.invalidFormat
    }

    // MARK: - Port Normalization

    /// 规范化所有配置的端口
    private func normalizeConfigs() {
        var usedListenPorts = Set<Int>()
        var usedRPCPorts = Set<Int>()

        for index in configs.indices {
            let original = configs[index]
            var updated = original

            updated.listenPort = firstAvailablePort(
                preferred: original.listenPort,
                fallbackStart: 11010,
                used: &usedListenPorts
            )
            updated.rpcPortalPort = firstAvailablePort(
                preferred: original.rpcPortalPort,
                fallbackStart: 15888,
                used: &usedRPCPorts
            )

            configs[index] = updated
        }
    }

    private func normalizedListenPort(for config: EasyTierConfig) -> Int {
        var usedPorts = Set(configs.map(\.listenPort))
        return firstAvailablePort(preferred: config.listenPort, fallbackStart: 11010, used: &usedPorts)
    }

    private func normalizedRPCPortalPort(for config: EasyTierConfig) -> Int {
        var usedPorts = Set(configs.map(\.rpcPortalPort))
        return firstAvailablePort(preferred: config.rpcPortalPort, fallbackStart: 15888, used: &usedPorts)
    }

    private func firstAvailablePort(preferred: Int, fallbackStart: Int, used: inout Set<Int>) -> Int {
        var candidate = preferred > 0 ? preferred : fallbackStart
        if candidate < 1 { candidate = fallbackStart }

        while used.contains(candidate) {
            candidate += 1
        }

        used.insert(candidate)
        return candidate
    }
}
