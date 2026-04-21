//
//  BinaryVersion.swift
//  EasyTierGUI
//
//  二进制版本信息模型
//

import Foundation

// MARK: - Binary Version

/// EasyTier 二进制版本信息
struct BinaryVersion: Codable, Equatable {
    /// 版本号 (e.g., "1.2.3")
    let version: String

    /// Git 标签名 (e.g., "v1.2.3")
    let tagName: String

    /// 发布说明 (Markdown)
    let releaseNotes: String?

    /// 下载链接 (根据架构选择)
    let downloadURL: URL

    /// 发布时间
    let publishedAt: Date

    // MARK: - Computed Properties

    /// 显示用的版本字符串
    var displayVersion: String {
        "v\(version)"
    }

    /// 发布说明摘要 (前 200 字符)
    var releaseNotesSummary: String {
        guard let notes = releaseNotes, !notes.isEmpty else {
            return "暂无更新说明"
        }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 {
            return trimmed
        }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 200)
        return String(trimmed[..<index]) + "..."
    }
}

// MARK: - Semantic Version Parsing

extension BinaryVersion {
    /// 解析语义化版本号
    /// - Returns: (major, minor, patch) 元组，解析失败返回 nil
    func semanticVersion() -> (major: Int, minor: Int, patch: Int)? {
        let versionString = version.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

        let components = versionString.split(separator: ".")
        guard components.count >= 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }

        return (major, minor, patch)
    }

    /// 比较版本号
    /// - Parameter other: 另一个版本
    /// - Returns: true 如果当前版本比 other 新
    func isNewer(than other: BinaryVersion) -> Bool {
        guard let current = semanticVersion(),
              let otherVersion = other.semanticVersion() else {
            // 无法解析时，使用字符串比较
            return version > other.version
        }

        if current.major != otherVersion.major {
            return current.major > otherVersion.major
        }
        if current.minor != otherVersion.minor {
            return current.minor > otherVersion.minor
        }
        return current.patch > otherVersion.patch
    }
}

// MARK: - Update State

/// 更新状态
enum UpdateState: Equatable {
    /// 未检查
    case notChecked
    /// 检查中
    case checking
    /// 有新版本可用
    case updateAvailable(BinaryVersion)
    /// 已是最新版本
    case upToDate
    /// 下载中 (进度 0.0-1.0)
    case downloading(Double)
    /// 下载完成，待安装
    case downloaded
    /// 安装完成
    case installed
    /// 错误
    case error(String)

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var isUpdateAvailable: Bool {
        if case .updateAvailable = self { return true }
        return false
    }
}

// MARK: - Binary Type

/// 二进制类型
enum BinaryType: String, CaseIterable {
    case core = "easytier-core"
    case cli = "easytier-cli"

    var displayName: String {
        switch self {
        case .core: return "EasyTier Core"
        case .cli: return "EasyTier CLI"
        }
    }
}
