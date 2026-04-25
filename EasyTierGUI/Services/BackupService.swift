//
//  BackupService.swift
//  EasyTierGUI
//
//  备份与恢复服务 - 导出/导入所有配置和应用偏好设置
//

import Foundation

// MARK: - Backup Error

enum BackupError: LocalizedError {
    case invalidFormat
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "备份文件格式无效"
        case .fileNotFound:
            return "备份文件不存在"
        }
    }
}

// MARK: - Preferences Backup

/// 应用偏好设置备份
struct PreferencesBackup: Codable {
    var startAtLogin: Bool
    var showMenuBar: Bool
    var autoConnectOnLaunch: Bool
    var showDockIcon: Bool
    var enableLogMonitoring: Bool
    var lastConnectedConfigId: String?

    init() {
        let defaults = UserDefaults.standard
        self.startAtLogin = defaults.bool(forKey: "startAtLogin")
        self.showMenuBar = defaults.bool(forKey: "showMenuBar")
        self.autoConnectOnLaunch = defaults.bool(forKey: "autoConnectOnLaunch")
        self.showDockIcon = defaults.bool(forKey: "showDockIcon")
        self.enableLogMonitoring = defaults.bool(forKey: "enableLogMonitoring")
        self.lastConnectedConfigId = defaults.string(forKey: "lastConnectedConfigId")
    }

    func apply() {
        let defaults = UserDefaults.standard
        defaults.set(startAtLogin, forKey: "startAtLogin")
        defaults.set(showMenuBar, forKey: "showMenuBar")
        defaults.set(autoConnectOnLaunch, forKey: "autoConnectOnLaunch")
        defaults.set(showDockIcon, forKey: "showDockIcon")
        defaults.set(enableLogMonitoring, forKey: "enableLogMonitoring")
        if let lastConnectedConfigId = lastConnectedConfigId {
            defaults.set(lastConnectedConfigId, forKey: "lastConnectedConfigId")
        } else {
            defaults.removeObject(forKey: "lastConnectedConfigId")
        }
    }
}

// MARK: - Backup Data

/// 完整备份数据
struct BackupData: Codable {
    var version: String = "1.0"
    var timestamp: Date
    var configs: [EasyTierConfig]
    var preferences: PreferencesBackup

    init(configs: [EasyTierConfig], preferences: PreferencesBackup) {
        self.timestamp = Date()
        self.configs = configs
        self.preferences = preferences
    }
}

// MARK: - Backup Service

/// 备份与恢复服务
class BackupService {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder = JSONDecoder()

    /// 创建备份数据
    func createBackupData(configManager: ConfigManager) -> BackupData {
        let preferences = PreferencesBackup()
        return BackupData(configs: configManager.configs, preferences: preferences)
    }

    /// 导出备份到文件
    func exportBackup(to url: URL, configManager: ConfigManager) throws {
        let backupData = createBackupData(configManager: configManager)
        let data = try encoder.encode(backupData)
        try data.write(to: url, options: .atomic)
    }

    /// 从文件导入备份
    func importBackup(from url: URL) throws -> BackupData {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BackupError.fileNotFound
        }

        let data = try Data(contentsOf: url)

        do {
            return try decoder.decode(BackupData.self, from: data)
        } catch {
            throw BackupError.invalidFormat
        }
    }

    /// 应用备份数据
    func applyBackup(_ backup: BackupData, configManager: ConfigManager) {
        // 直接覆盖所有配置
        configManager.configs = backup.configs

        // 应用偏好设置
        backup.preferences.apply()
    }
}
