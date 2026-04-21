//
//  BinaryManager.swift
//  EasyTierGUI
//
//  二进制管理器 - 管理内置和用户安装的二进制文件
//

import Foundation
import Combine

// MARK: - Binary Manager

/// 二进制管理器
@MainActor
final class BinaryManager: ObservableObject {

    // MARK: - Singleton

    static let shared = BinaryManager()

    // MARK: - Published Properties

    /// 当前安装的版本
    @Published private(set) var currentVersion: String?

    /// 更新状态
    @Published private(set) var updateState: UpdateState = .notChecked

    /// 可用的最新版本
    @Published private(set) var latestVersion: BinaryVersion?

    /// 是否正在检查更新
    @Published private(set) var isCheckingForUpdate = false

    /// 下载进度 (0.0 - 1.0)
    @Published private(set) var downloadProgress: Double = 0

    // MARK: - UserDefaults Keys

    private let kInstalledVersion = "easytierInstalledVersion"
    private let kBundledVersion = "easytierBundledVersion"
    private let kLastUpdateCheck = "easytierLastUpdateCheck"
    private let kSkipVersion = "easytierSkipVersion"

    // MARK: - Initialization

    private init() {
        // 确保用户目录存在
        try? FileManager.default.createDirectory(at: Self.userBinDir, withIntermediateDirectories: true)

        // 检测当前版本
        Task {
            await detectCurrentVersion()
        }
    }

    // MARK: - Path Resolution

    /// 用户目录路径
    static let userBinDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EasyTierGUI/bin", isDirectory: true)
    }()

    /// 内置资源目录路径
    static let bundledBinDir: URL = {
        let bundle = Bundle.main
        return bundle.url(forResource: "easytier", withExtension: nil) ?? bundle.bundleURL
    }()

    /// 解析二进制文件路径（静态方法，可从任何上下文调用）
    /// - Parameter type: 二进制类型
    /// - Returns: 文件路径，优先返回用户目录中的版本
    nonisolated static func resolveBinaryPath(for type: BinaryType) -> URL {
        // 优先使用用户目录（已更新的版本）
        let userBinary = userBinDir.appendingPathComponent(type.rawValue)
        if FileManager.default.isExecutableFile(atPath: userBinary.path) {
            return userBinary
        }

        // 其次使用内置版本
        let bundledBinary = bundledBinDir.appendingPathComponent(type.rawValue)
        if FileManager.default.isExecutableFile(atPath: bundledBinary.path) {
            return bundledBinary
        }

        // 返回用户目录路径（错误处理由调用方负责）
        return userBinary
    }

    /// 解析二进制文件路径
    /// - Parameter type: 二进制类型
    /// - Returns: 文件路径，优先返回用户目录中的版本
    func binaryPath(for type: BinaryType) -> URL {
        Self.resolveBinaryPath(for: type)
    }

    /// 检查二进制文件是否存在
    func binaryExists(for type: BinaryType) -> Bool {
        let path = binaryPath(for: type)
        return FileManager.default.isExecutableFile(atPath: path.path)
    }

    /// 检查二进制文件是否存在（静态方法）
    nonisolated static func checkBinaryExists(for type: BinaryType) -> Bool {
        let path = resolveBinaryPath(for: type)
        return FileManager.default.isExecutableFile(atPath: path.path)
    }

    /// 二进制文件来源
    enum BinarySource {
        case bundled    // 内置版本
        case installed  // 用户安装/更新的版本
        case none       // 不存在
    }

    /// 获取二进制文件来源
    func binarySource(for type: BinaryType) -> BinarySource {
        let userBinary = Self.userBinDir.appendingPathComponent(type.rawValue)
        if FileManager.default.isExecutableFile(atPath: userBinary.path) {
            return .installed
        }

        let bundledBinary = Self.bundledBinDir.appendingPathComponent(type.rawValue)
        if FileManager.default.isExecutableFile(atPath: bundledBinary.path) {
            return .bundled
        }

        return .none
    }

    // MARK: - Version Detection

    /// 检测当前安装的版本
    private func detectCurrentVersion() async {
        let corePath = binaryPath(for: .core)

        guard FileManager.default.isExecutableFile(atPath: corePath.path) else {
            currentVersion = nil
            return
        }

        // 运行 easytier-core -V 获取版本
        let version = await runCoreVersion(at: corePath)
        currentVersion = version

        // 如果是用户安装的版本，保存到 UserDefaults
        if binarySource(for: .core) == .installed {
            UserDefaults.standard.set(version, forKey: kInstalledVersion)
        }
    }

    private func runCoreVersion(at path: URL) async -> String? {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = path
            task.arguments = ["-V"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // 解析版本号，格式可能是 "easytier-core 1.2.3" 或 "v1.2.3" 或 "1.2.3"
                let version = parseVersionString(output)
                continuation.resume(returning: version)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func parseVersionString(_ output: String) -> String? {
        // 尝试多种格式
        // 1. "easytier-core 1.2.3"
        // 2. "v1.2.3"
        // 3. "1.2.3"

        let pattern = #"(?:easytier-core\s+)?v?(\d+\.\d+\.\d+)"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return output.isEmpty ? nil : output
        }

        return String(output[range])
    }

    // MARK: - Update Check

    /// 检查更新
    /// - Parameter force: 是否强制检查（忽略缓存）
    func checkForUpdate(force: Bool = false) async {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true
        updateState = .checking

        do {
            let release = try await GitHubReleaseService.shared.fetchLatestRelease(useCache: !force)
            latestVersion = release

            // 比较版本
            let currentVer = createCurrentVersionObject()
            if let current = currentVer, release.isNewer(than: current) {
                // 检查用户是否跳过了此版本
                let skipVersion = UserDefaults.standard.string(forKey: kSkipVersion)
                if skipVersion == release.tagName {
                    updateState = .notChecked // 静默处理跳过的版本
                } else {
                    updateState = .updateAvailable(release)
                }
            } else {
                updateState = .upToDate
            }

            UserDefaults.standard.set(Date(), forKey: kLastUpdateCheck)
        } catch {
            updateState = .error(error.localizedDescription)
        }

        isCheckingForUpdate = false
    }

    private func createCurrentVersionObject() -> BinaryVersion? {
        guard let version = currentVersion else { return nil }

        return BinaryVersion(
            version: version,
            tagName: "v\(version)",
            releaseNotes: nil,
            downloadURL: URL(string: "https://example.com")!,
            publishedAt: Date()
        )
    }

    // MARK: - Download & Install

    /// 下载并安装更新
    /// - Parameter version: 要安装的版本
    func downloadAndInstall(version: BinaryVersion) async throws {
        updateState = .downloading(0)
        downloadProgress = 0

        // 下载
        let zipFile = try await GitHubReleaseService.shared.downloadBinary(
            version: version,
            progress: { progress in
                Task { @MainActor in
                    self.downloadProgress = progress
                    self.updateState = .downloading(progress)
                }
            }
        )

        updateState = .downloading(1.0)

        // 解压并安装
        try await install(from: zipFile)

        // 更新状态
        currentVersion = version.version
        UserDefaults.standard.set(version.version, forKey: kInstalledVersion)
        updateState = .installed
    }

    private func install(from zipFile: URL) async throws {
        // 创建临时解压目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyTierGUI-Extract-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // 使用 unzip 解压
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", zipFile.path, "-d", tempDir.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw InstallError.unzipFailed
        }

        // 查找并移动二进制文件
        try moveBinaries(from: tempDir)

        // 清理 zip 文件
        try? FileManager.default.removeItem(at: zipFile)
    }

    private func moveBinaries(from extractDir: URL) throws {
        // 确保用户目录存在
        try FileManager.default.createDirectory(at: Self.userBinDir, withIntermediateDirectories: true)

        // 遍历解压目录，查找二进制文件
        guard let enumerator = FileManager.default.enumerator(
            at: extractDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw InstallError.binaryNotFound
        }

        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent

            // 检查是否是我们要的二进制文件
            guard fileName == "easytier-core" || fileName == "easytier-cli" else {
                continue
            }

            // 检查是否是可执行文件
            guard FileManager.default.isExecutableFile(atPath: fileURL.path) else {
                continue
            }

            let destination = Self.userBinDir.appendingPathComponent(fileName)

            // 如果目标已存在，先删除
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }

            // 移动文件
            try FileManager.default.moveItem(at: fileURL, to: destination)

            // 确保可执行权限
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destination.path
            )
        }
    }

    // MARK: - Skip Version

    /// 跳过当前可用版本
    func skipCurrentVersion() {
        guard let version = latestVersion else { return }
        UserDefaults.standard.set(version.tagName, forKey: kSkipVersion)
        updateState = .notChecked
    }

    // MARK: - Reset

    /// 重置更新状态
    func resetUpdateState() {
        updateState = .notChecked
        latestVersion = nil
        downloadProgress = 0
    }

    /// 清除用户安装的版本（回退到内置版本）
    func clearInstalledVersion() throws {
        for type in BinaryType.allCases {
            let path = Self.userBinDir.appendingPathComponent(type.rawValue)
            if FileManager.default.fileExists(atPath: path.path) {
                try FileManager.default.removeItem(at: path)
            }
        }

        UserDefaults.standard.removeObject(forKey: kInstalledVersion)
        UserDefaults.standard.removeObject(forKey: kSkipVersion)

        Task {
            await detectCurrentVersion()
        }
    }
}

// MARK: - Install Errors

enum InstallError: LocalizedError {
    case unzipFailed
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .unzipFailed:
            return "解压文件失败"
        case .binaryNotFound:
            return "在下载的文件中未找到二进制程序"
        }
    }
}
