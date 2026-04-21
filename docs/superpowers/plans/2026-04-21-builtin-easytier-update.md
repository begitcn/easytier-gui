# EasyTier 内置二进制与自动更新实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 easytier-core 和 easytier-cli 内置到应用中，支持从 GitHub 自动检测和更新核心版本。

**Architecture:** 使用 BinaryManager 管理二进制路径解析（优先用户目录 > 内置资源），GitHubReleaseService 处理 API 调用和下载，更新文件存储在用户目录不影响 app 签名。

**Tech Stack:** Swift, SwiftUI, Foundation (URLSession), GitHub REST API

---

## 文件结构

### 新建文件

| 文件 | 职责 |
|------|------|
| `EasyTierGUI/Models/BinaryVersion.swift` | 版本信息数据模型 |
| `EasyTierGUI/Services/BinaryManager.swift` | 二进制路径管理、版本检测、更新协调 |
| `EasyTierGUI/Services/GitHubReleaseService.swift` | GitHub API 调用、版本检查、文件下载 |
| `EasyTierGUI/Views/Components/UpdateBanner.swift` | 更新提示横幅组件 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `EasyTierGUI/Services/EasyTierService.swift` | 使用 BinaryManager 获取二进制路径 |
| `EasyTierGUI/Views/SettingsView.swift` | 显示版本信息、检查更新按钮、更新状态 |
| `EasyTierGUI/Services/ProcessViewModel.swift` | 初始化时触发后台更新检查 |
| `build.sh` | 构建时下载并嵌入默认版本二进制 |

---

## Task 1: 创建 BinaryVersion 数据模型

**Files:**
- Create: `EasyTierGUI/Models/BinaryVersion.swift`

- [ ] **Step 1: 创建 BinaryVersion.swift 文件**

```swift
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
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功，无错误

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Models/BinaryVersion.swift
git commit -m "$(cat <<'EOF'
feat: add BinaryVersion model for version management

Add data models for binary version tracking:
- BinaryVersion: version info, semantic version parsing, comparison
- UpdateState: tracking update check/download/install states
- BinaryType: easytier-core and easytier-cli types

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 创建 GitHubReleaseService

**Files:**
- Create: `EasyTierGUI/Services/GitHubReleaseService.swift`

- [ ] **Step 1: 创建 GitHubReleaseService.swift 文件**

```swift
//
//  GitHubReleaseService.swift
//  EasyTierGUI
//
//  GitHub Release 服务 - 获取版本信息和下载文件
//

import Foundation

// MARK: - GitHub Release Service

/// GitHub Release 服务
actor GitHubReleaseService {

    // MARK: - Singleton

    static let shared = GitHubReleaseService()

    // MARK: - Constants

    private let githubAPIBase = "https://api.github.com/repos/EasyTier/EasyTier"
    private let userAgent = "EasyTierGUI/1.0"

    // MARK: - Properties

    private let session: URLSession
    private var cachedLatestRelease: BinaryVersion?
    private var lastCheckTime: Date?

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// 获取最新版本信息
    /// - Parameter useCache: 是否使用缓存（5分钟内）
    /// - Returns: 最新版本信息
    func fetchLatestRelease(useCache: Bool = true) async throws -> BinaryVersion {
        // 检查缓存（5分钟有效）
        if useCache, let cached = cachedLatestRelease, let lastCheck = lastCheckTime {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < 300 { // 5 minutes
                return cached
            }
        }

        let url = URL(string: "\(githubAPIBase)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 403:
            throw GitHubError.rateLimited
        case 404:
            throw GitHubError.releaseNotFound
        default:
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        let release = try parseRelease(data)
        cachedLatestRelease = release
        lastCheckTime = Date()
        return release
    }

    /// 下载二进制文件
    /// - Parameters:
    ///   - version: 版本信息
    ///   - progress: 进度回调
    /// - Returns: 下载文件的临时路径
    func downloadBinary(version: BinaryVersion, progress: @escaping (Double) -> Void) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EasyTierGUI-Downloads", isDirectory: true)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileName = version.downloadURL.lastPathComponent
        let destination = tempDir.appendingPathComponent(fileName)

        // 如果已存在同名文件，删除它
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        var request = URLRequest(url: version.downloadURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (asyncBytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.downloadFailed
        }

        let expectedLength = httpResponse.expectedContentLength
        var receivedLength: Int64 = 0

        // 创建文件句柄
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: destination)

        defer {
            try? fileHandle.close()
        }

        // 流式写入
        for try await byte in asyncBytes {
            try fileHandle.write(contentsOf: [byte])
            receivedLength += 1

            if expectedLength > 0 {
                let progressValue = Double(receivedLength) / Double(expectedLength)
                await MainActor.run {
                    progress(progressValue)
                }
            }
        }

        await MainActor.run {
            progress(1.0)
        }

        return destination
    }

    // MARK: - Private Methods

    private func parseRelease(_ data: Data) throws -> BinaryVersion {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubError.invalidJSON
        }

        guard let tagName = json["tag_name"] as? String else {
            throw GitHubError.missingField("tag_name")
        }

        // 解析版本号 (去掉 'v' 前缀)
        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        // 获取发布说明
        let releaseNotes = json["body"] as? String

        // 发布时间
        var publishedAt = Date()
        if let publishedStr = json["published_at"] as? String {
            let formatter = ISO8601DateFormatter()
            publishedAt = formatter.date(from: publishedStr) ?? Date()
        }

        // 查找适合当前架构的下载链接
        guard let assets = json["assets"] as? [[String: Any]] else {
            throw GitHubError.missingField("assets")
        }

        let downloadURL = try findDownloadURL(for: assets)
        if downloadURL == nil {
            throw GitHubError.assetNotFound
        }

        return BinaryVersion(
            version: version,
            tagName: tagName,
            releaseNotes: releaseNotes,
            downloadURL: downloadURL!,
            publishedAt: publishedAt
        )
    }

    private func findDownloadURL(for assets: [[String: Any]]) -> URL? {
        // 根据当前架构选择下载文件
        // arm64: apple-darwin-arm64
        // x86_64: apple-darwin-x86_64
        #if arch(arm64)
        let archPattern = "apple-darwin-arm64"
        #elseif arch(x86_64)
        let archPattern = "apple-darwin-x86_64"
        #else
        let archPattern = "apple-darwin"
        #endif

        for asset in assets {
            guard let name = asset["name"] as? String,
                  let urlString = asset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                continue
            }

            // 匹配架构
            if name.contains(archPattern) && name.hasSuffix(".zip") {
                return url
            }
        }

        return nil
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case invalidResponse
    case invalidJSON
    case missingField(String)
    case httpError(Int)
    case rateLimited
    case releaseNotFound
    case assetNotFound
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的服务器响应"
        case .invalidJSON:
            return "无法解析服务器返回的数据"
        case .missingField(let field):
            return "缺少必要字段: \(field)"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .rateLimited:
            return "GitHub API 请求频率限制，请稍后再试"
        case .releaseNotFound:
            return "未找到发布版本"
        case .assetNotFound:
            return "未找到适合当前架构的下载文件"
        case .downloadFailed:
            return "下载失败"
        }
    }
}
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Services/GitHubReleaseService.swift
git commit -m "$(cat <<'EOF'
feat: add GitHubReleaseService for version check and download

- Fetch latest release info from GitHub API
- Parse release assets for current architecture
- Stream download with progress callback
- Cache API responses for 5 minutes

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 创建 BinaryManager

**Files:**
- Create: `EasyTierGUI/Services/BinaryManager.swift`

- [ ] **Step 1: 创建 BinaryManager.swift 文件**

```swift
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

    // MARK: - Constants

    private let userBinDir: URL
    private let bundledBinDir: URL

    // MARK: - UserDefaults Keys

    private let kInstalledVersion = "easytierInstalledVersion"
    private let kBundledVersion = "easytierBundledVersion"
    private let kLastUpdateCheck = "easytierLastUpdateCheck"
    private let kSkipVersion = "easytierSkipVersion"

    // MARK: - Initialization

    private init() {
        // 用户目录: ~/Library/Application Support/EasyTierGUI/bin/
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        userBinDir = appSupport.appendingPathComponent("EasyTierGUI/bin", isDirectory: true)

        // 内置资源目录: Contents/Resources/easytier/
        let bundle = Bundle.main
        bundledBinDir = bundle.url(forResource: "easytier", withExtension: nil) ?? bundle.bundleURL

        // 确保用户目录存在
        try? FileManager.default.createDirectory(at: userBinDir, withIntermediateDirectories: true)

        // 检测当前版本
        Task {
            await detectCurrentVersion()
        }
    }

    // MARK: - Path Resolution

    /// 解析二进制文件路径
    /// - Parameter type: 二进制类型
    /// - Returns: 文件路径，优先返回用户目录中的版本
    func binaryPath(for type: BinaryType) -> URL {
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

    /// 检查二进制文件是否存在
    func binaryExists(for type: BinaryType) -> Bool {
        let path = binaryPath(for: type)
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
        let userBinary = userBinDir.appendingPathComponent(type.rawValue)
        if FileManager.default.isExecutableFile(atPath: userBinary.path) {
            return .installed
        }

        let bundledBinary = bundledBinDir.appendingPathComponent(type.rawValue)
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
        try FileManager.default.createDirectory(at: userBinDir, withIntermediateDirectories: true)

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

            let destination = userBinDir.appendingPathComponent(fileName)

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
            let path = userBinDir.appendingPathComponent(type.rawValue)
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
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Services/BinaryManager.swift
git commit -m "$(cat <<'EOF'
feat: add BinaryManager for binary path and version management

- Resolve binary paths (user installed > bundled)
- Detect current installed version
- Check for updates from GitHub
- Download and install new versions
- Track update states and progress

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: 创建 UpdateBanner 组件

**Files:**
- Create: `EasyTierGUI/Views/Components/UpdateBanner.swift`

- [ ] **Step 1: 创建 Views/Components 目录并添加 UpdateBanner.swift**

```swift
//
//  UpdateBanner.swift
//  EasyTierGUI
//
//  更新提示横幅组件
//

import SwiftUI

// MARK: - Update Banner

/// 更新提示横幅
struct UpdateBanner: View {
    let version: BinaryVersion
    let onUpdate: () -> Void
    let onSkip: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主横幅
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("发现新版本 \(version.displayVersion)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("点击展开查看更新内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onUpdate) {
                    Text("更新")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // 展开的详情
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("更新内容")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(version.releaseNotesSummary)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Download Progress Banner

/// 下载进度横幅
struct DownloadProgressBanner: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("正在更新...")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Update Complete Banner

/// 更新完成横幅
struct UpdateCompleteBanner: View {
    let version: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("更新完成")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("已安装版本 v\(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("确定")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Banner

/// 错误横幅
struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("更新失败")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRetry) {
                Text("重试")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Update Available") {
    UpdateBanner(
        version: BinaryVersion(
            version: "1.2.5",
            tagName: "v1.2.5",
            releaseNotes: "## 新功能\n- 支持自动更新\n- 修复连接稳定性问题\n\n## 改进\n- 性能优化",
            downloadURL: URL(string: "https://example.com")!,
            publishedAt: Date()
        ),
        onUpdate: {},
        onSkip: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Download Progress") {
    DownloadProgressBanner(progress: 0.65)
        .padding()
        .frame(width: 400)
}

#Preview("Update Complete") {
    UpdateCompleteBanner(version: "1.2.5", onDismiss: {})
        .padding()
        .frame(width: 400)
}

#Preview("Error") {
    ErrorBanner(message: "网络连接失败", onRetry: {}, onDismiss: {})
        .padding()
        .frame(width: 400)
}
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Views/Components/UpdateBanner.swift
git commit -m "$(cat <<'EOF'
feat: add UpdateBanner components for update UI

- UpdateBanner: show new version with expandable release notes
- DownloadProgressBanner: show download progress
- UpdateCompleteBanner: show success after update
- ErrorBanner: show error with retry option

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 修改 EasyTierService 使用 BinaryManager

**Files:**
- Modify: `EasyTierGUI/Services/EasyTierService.swift`

- [ ] **Step 1: 修改 EasyTierService.swift，移除手动路径配置，使用 BinaryManager**

找到 `EasyTierService.swift` 文件，修改以下部分：

1. 删除 `configuredPath` 计算属性（第 75-77 行）

2. 替换 `executablePath` 计算属性为：
```swift
    /// 解析后的可执行文件路径
    var executablePath: String {
        BinaryManager.shared.binaryPath(for: .core).path
    }
```

3. 修改 `easytierCLIPath()` 方法为：
```swift
    private func easytierCLIPath() -> String? {
        let path = BinaryManager.shared.binaryPath(for: .cli)
        return FileManager.default.isExecutableFile(atPath: path.path) ? path.path : nil
    }
```

4. 删除 `resolvedBinaryPath(for:)` 方法（第 405-432 行）

完整的修改后代码：

```swift
// 在文件顶部不需要额外 import

// MARK: - EasyTier Service

/// EasyTier 服务 - 管理 easytier-core 进程
class EasyTierService: ObservableObject {

    // MARK: - Published Properties

    @Published var isRunning = false
    @Published var processOutput = ""
    @Published var logEntries: [LogEntry] = []

    // MARK: - Memory Management

    private let maxOutputLength = 50_000  // 最大输出缓冲 (约 50KB)
    private let maxLogEntries = 100       // 最大日志条数

    // MARK: - Private Properties

    private var process: Process?
    private var outputPipe: Pipe?
    private var logFileHandle: FileHandle?
    private var privilegedLogTimer: Timer?
    private var privilegedLogOffset: UInt64 = 0
    private var privilegedPID: Int32?

    /// 解析后的可执行文件路径
    var executablePath: String {
        BinaryManager.shared.binaryPath(for: .core).path
    }
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Services/EasyTierService.swift
git commit -m "$(cat <<'EOF'
refactor: use BinaryManager for binary path resolution

- Remove manual path configuration via UserDefaults
- Use BinaryManager.shared to resolve binary paths
- Simplify easytierCLIPath() method

Breaking change: removes easytierPath UserDefaults key

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 修改 SettingsView 显示版本信息和更新 UI

**Files:**
- Modify: `EasyTierGUI/Views/SettingsView.swift`

- [ ] **Step 1: 重写 SettingsView.swift 的 EasyTier 部分**

替换整个 SettingsView 的 body 内容：

```swift
//
//  SettingsView.swift
//  EasyTierGUI
//
//  应用设置和偏好
//

import SwiftUI
import ServiceManagement

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @StateObject private var binaryManager = BinaryManager.shared

    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("autoConnectOnLaunch") private var autoConnectOnLaunch = false
    @AppStorage("showDockIcon") private var showDockIcon = true

    @State private var openAtLoginManager = OpenAtLoginManager()
    @State private var showVisibilityAlert = false
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Form {
                    // MARK: - EasyTier Section
                    Section(header: Text("EasyTier").font(.system(.subheadline, design: .rounded))) {
                        // 更新状态横幅
                        updateBannerSection

                        // 版本信息
                        versionInfoSection

                        // 更新操作按钮
                        updateActionSection
                    }

                    // MARK: - 通用 Section
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

                    // MARK: - 关于 Section
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
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await checkForUpdateIfNeeded()
            }
        }
        .alert("无法保存设置", isPresented: $showVisibilityAlert) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("必须保留至少一个可见入口（系统托盘或程序坞），以确保您可以访问应用程序。")
        }
        .confirmationDialog(
            "确定要重置到内置版本吗？",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置", role: .destructive) {
                resetToBundledVersion()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("这将删除已安装的更新版本，回退到应用内置的版本。")
        }
    }

    // MARK: - Update Banner Section

    @ViewBuilder
    private var updateBannerSection: some View {
        switch binaryManager.updateState {
        case .updateAvailable(let version):
            UpdateBanner(
                version: version,
                onUpdate: { startUpdate() },
                onSkip: { binaryManager.skipCurrentVersion() }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        case .downloading(let progress):
            DownloadProgressBanner(progress: progress)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        case .installed:
            if let version = binaryManager.currentVersion {
                UpdateCompleteBanner(
                    version: version,
                    onDismiss: { binaryManager.resetUpdateState() }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

        case .error(let message):
            ErrorBanner(
                message: message,
                onRetry: { Task { await binaryManager.checkForUpdate(force: true) } },
                onDismiss: { binaryManager.resetUpdateState() }
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

        default:
            EmptyView()
        }
    }

    // MARK: - Version Info Section

    @ViewBuilder
    private var versionInfoSection: some View {
        // 当前版本
        LabeledContent("当前版本") {
            HStack(spacing: 6) {
                if let version = binaryManager.currentVersion {
                    Text("v\(version)")
                        .foregroundColor(.primary)

                    // 版本来源标签
                    let source = binaryManager.binarySource(for: .core)
                    Text(source == .installed ? "已安装" : "内置")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(source == .installed ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .foregroundColor(source == .installed ? .blue : .secondary)
                        .cornerRadius(4)
                } else {
                    Text("未安装")
                        .foregroundColor(.secondary)
                }
            }
        }

        // 最新版本
        if let latest = binaryManager.latestVersion {
            LabeledContent("最新版本") {
                Text(latest.displayVersion)
                    .foregroundColor(binaryManager.updateState.isUpdateAvailable ? .blue : .secondary)
            }
        }

        // 上次检查时间
        if let lastCheck = UserDefaults.standard.object(forKey: "easytierLastUpdateCheck") as? Date {
            LabeledContent("上次检查") {
                Text(lastCheck, style: .relative)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Update Action Section

    @ViewBuilder
    private var updateActionSection: some View {
        HStack(spacing: 12) {
            // 检查更新按钮
            Button {
                Task {
                    await binaryManager.checkForUpdate(force: true)
                }
            } label: {
                if binaryManager.isCheckingForUpdate {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Text("检查更新")
                }
            }
            .disabled(binaryManager.isCheckingForUpdate || isUpdating)

            // 重置按钮（仅当有用户安装版本时显示）
            if binaryManager.binarySource(for: .core) == .installed {
                Button("重置到内置版本") {
                    showResetConfirmation = true
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isUpdating: Bool {
        if case .downloading = binaryManager.updateState { return true }
        return false
    }

    // MARK: - Actions

    private func checkForUpdateIfNeeded() async {
        // 检查是否需要自动检查（启动后 2 秒，且超过 24 小时未检查）
        guard !binaryManager.isCheckingForUpdate else { return }

        if let lastCheck = UserDefaults.standard.object(forKey: "easytierLastUpdateCheck") as? Date {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed < 86400 { // 24 hours
                return
            }
        }

        // 延迟 2 秒后检查
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        await binaryManager.checkForUpdate()
    }

    private func startUpdate() {
        guard let version = binaryManager.latestVersion else { return }

        Task {
            do {
                try await binaryManager.downloadAndInstall(version: version)
            } catch {
                // 错误已在 BinaryManager 中处理
            }
        }
    }

    private func resetToBundledVersion() {
        do {
            try binaryManager.clearInstalledVersion()
        } catch {
            print("Failed to reset: \(error)")
        }
    }
}

// MARK: - Open At Login Manager

struct OpenAtLoginManager {
    private let bundleID = Bundle.main.bundleIdentifier ?? "cn.begitcn.EasyTierGUI"

    func setStartAtLogin(_ enabled: Bool) {
        #if os(macOS)
        if #available(macOS 13.0, *) {
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
            SMLoginItemSetEnabled(bundleID as CFString, enabled)
        }
        #endif
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(ProcessViewModel())
        .frame(width: 550, height: 600)
}
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Views/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat: add version info and update UI to SettingsView

- Show current version with source (bundled/installed)
- Show latest version when available
- Add update banner with download progress
- Add check for update button
- Add reset to bundled version option
- Auto check for updates on appear (24h interval)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 修改 ProcessViewModel 触发更新检查

**Files:**
- Modify: `EasyTierGUI/Services/ProcessViewModel.swift`

- [ ] **Step 1: 修改 ProcessViewModel 初始化，触发后台更新检查**

在 `ProcessViewModel` 类中修改 `init()` 方法，在最后添加更新检查：

找到 `init()` 方法（约第 145-165 行），在 `cancellables` 订阅之后添加：

```swift
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
```

并在类中添加 `checkForBinaryUpdate()` 方法：

```swift
    // MARK: - Binary Update Check

    private func checkForBinaryUpdate() async {
        await BinaryManager.shared.checkForUpdate()
    }
```

同时修改 `easytierCoreExists` 计算属性，使用 BinaryManager：

```swift
    /// 检测 easytier-core 是否存在
    var easytierCoreExists: Bool {
        BinaryManager.shared.binaryExists(for: .core)
    }
```

- [ ] **Step 2: 验证文件编译**

运行: `xcodebuild build -project EasyTierGUI.xcodeproj -scheme EasyTierGUI -configuration Debug -derivedDataPath .build/DerivedData ONLY_ACTIVE_ARCH=YES -quiet 2>&1 | head -20`
预期: 编译成功

- [ ] **Step 3: 提交**

```bash
git add EasyTierGUI/Services/ProcessViewModel.swift
git commit -m "$(cat <<'EOF'
feat: trigger binary update check on app launch

- Add background update check 3 seconds after launch
- Use BinaryManager for core existence check
- Remove dependency on easytierPath UserDefaults

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: 修改 build.sh 嵌入二进制文件

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: 修改 build.sh，在构建前下载并嵌入二进制文件**

替换整个 `build.sh` 内容：

```bash
#!/bin/bash
# Build script for EasyTier GUI
# Supports Universal Binary (arm64 + x86_64)

set -e

echo "Building EasyTierGUI..."

CONFIGURATION=${1:-Release}
DERIVED_DATA_PATH="$PWD/.build/DerivedData"
RESOURCES_DIR="$PWD/EasyTierGUI/Resources/easytier"

# MARK: - Download EasyTier Binaries

echo ""
echo "Checking EasyTier binaries..."

# 创建资源目录
mkdir -p "$RESOURCES_DIR"

# 获取最新版本信息
echo "Fetching latest release info from GitHub..."
LATEST_RELEASE_JSON=$(curl -s https://api.github.com/repos/EasyTier/EasyTier/releases/latest)

# 提取版本号
LATEST_VERSION=$(echo "$LATEST_RELEASE_JSON" | grep -m1 '"tag_name"' | sed 's/.*"tag_name": "\([^"]*\)".*/\1/')
echo "Latest version: $LATEST_VERSION"

# 根据架构选择下载文件
ARCH=$(uname -m)
case $ARCH in
    arm64)
        ASSET_PATTERN="apple-darwin-arm64"
        ;;
    x86_64)
        ASSET_PATTERN="apple-darwin-x86_64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Architecture: $ARCH, looking for: *$ASSET_PATTERN*.zip"

# 提取下载 URL
DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep -E "\"browser_download_url\".*$ASSET_PATTERN.*\.zip\"" | sed 's/.*"browser_download_url": "\([^"]*\)".*/\1/' | head -1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Warning: Could not find download URL for architecture $ARCH"
    echo "Falling back to universal or any available asset..."
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | grep -E "\"browser_download_url\".*darwin.*\.zip\"" | sed 's/.*"browser_download_url": "\([^"]*\)".*/\1/' | head -1)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: No suitable download found"
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

# 检查是否需要下载
CORE_BINARY="$RESOURCES_DIR/easytier-core"
NEED_DOWNLOAD=false

if [ ! -f "$CORE_BINARY" ]; then
    NEED_DOWNLOAD=true
else
    # 检查版本是否匹配
    CURRENT_VERSION=$("$CORE_BINARY" -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    LATEST_VERSION_NUM=$(echo "$LATEST_VERSION" | sed 's/v//')
    if [ "$CURRENT_VERSION" != "$LATEST_VERSION_NUM" ]; then
        echo "Version mismatch: current=$CURRENT_VERSION, latest=$LATEST_VERSION_NUM"
        NEED_DOWNLOAD=true
    else
        echo "Binaries up to date: $CURRENT_VERSION"
    fi
fi

if [ "$NEED_DOWNLOAD" = true ]; then
    echo "Downloading EasyTier binaries..."
    TEMP_ZIP="/tmp/easytier-$LATEST_VERSION.zip"

    curl -L -o "$TEMP_ZIP" "$DOWNLOAD_URL"

    echo "Extracting binaries..."
    TEMP_DIR="/tmp/easytier-extract-$$"
    mkdir -p "$TEMP_DIR"
    unzip -q -o "$TEMP_ZIP" -d "$TEMP_DIR"

    # 查找并移动二进制文件
    find "$TEMP_DIR" -name "easytier-core" -type f -exec mv {} "$RESOURCES_DIR/" \; 2>/dev/null || true
    find "$TEMP_DIR" -name "easytier-cli" -type f -exec mv {} "$RESOURCES_DIR/" \; 2>/dev/null || true

    # 设置可执行权限
    chmod +x "$RESOURCES_DIR/easytier-core" 2>/dev/null || true
    chmod +x "$RESOURCES_DIR/easytier-cli" 2>/dev/null || true

    # 清理
    rm -rf "$TEMP_DIR" "$TEMP_ZIP"

    # 验证
    if [ -f "$RESOURCES_DIR/easytier-core" ]; then
        echo "Binaries extracted successfully"
        "$RESOURCES_DIR/easytier-core" -V || true
    else
        echo "Warning: easytier-core not found in downloaded archive"
    fi
fi

# MARK: - Build

echo ""
echo "Starting Xcode build..."

# Clean previous build to ensure Universal Binary
rm -rf "$DERIVED_DATA_PATH"

# Build Universal Binary
# ONLY_ACTIVE_ARCH=NO forces building for all architectures in ARCHS setting
xcodebuild build \
    -project EasyTierGUI.xcodeproj \
    -scheme EasyTierGUI \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    -quiet

echo ""
echo "Build complete!"
echo "App location: $DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app"
echo ""
echo "Architecture support:"
lipo -archs "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app/Contents/MacOS/EasyTierGUI"

# MARK: - Verify Embedded Binaries

echo ""
echo "Verifying embedded binaries..."
APP_RESOURCES="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/EasyTierGUI.app/Contents/Resources/easytier"
if [ -f "$APP_RESOURCES/easytier-core" ]; then
    echo "✓ easytier-core embedded"
    "$APP_RESOURCES/easytier-core" -V 2>/dev/null || true
else
    echo "✗ easytier-core NOT found in app bundle"
fi
if [ -f "$APP_RESOURCES/easytier-cli" ]; then
    echo "✓ easytier-cli embedded"
else
    echo "✗ easytier-cli NOT found in app bundle"
fi
```

- [ ] **Step 2: 确保 Xcode 项目包含 Resources 目录**

检查并确保 Resources 目录在 Xcode 项目中：

运行: `ls -la EasyTierGUI/Resources/ 2>/dev/null || mkdir -p EasyTierGUI/Resources/easytier`
预期: 目录存在或创建成功

- [ ] **Step 3: 测试构建脚本**

运行: `./build.sh Debug 2>&1 | tail -30`
预期: 构建成功，二进制文件嵌入成功

- [ ] **Step 4: 提交**

```bash
git add build.sh
git commit -m "$(cat <<'EOF'
feat: embed EasyTier binaries during build

- Download latest release from GitHub before build
- Select correct architecture (arm64/x86_64)
- Extract and embed in app bundle Resources
- Skip download if binaries are up to date
- Verify embedded binaries after build

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: 最终验证与集成测试

**Files:**
- N/A

- [ ] **Step 1: 完整构建测试**

运行: `./build.sh Release`
预期: 构建成功，二进制文件嵌入成功

- [ ] **Step 2: 验证应用启动**

运行: `open .build/DerivedData/Build/Products/Release/EasyTierGUI.app`
预期: 应用正常启动

- [ ] **Step 3: 验证设置页面**

在应用中打开设置页面，验证：
- 当前版本显示正确
- 检查更新按钮可用
- 更新横幅正常显示

- [ ] **Step 4: 最终提交**

```bash
git add -A
git commit -m "$(cat <<'EOF'
feat: complete built-in EasyTier binaries with auto-update

Features:
- Embed easytier-core and easytier-cli in app bundle
- Auto check for updates from GitHub on launch
- Download and install updates with progress UI
- Support both arm64 and x86_64 architectures
- Reset to bundled version option

Breaking changes:
- Removed easytierPath UserDefaults key
- Users no longer need to manually configure binary path

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## 自检清单

**1. Spec 覆盖检查:**
- [x] 内置默认版本 - Task 8 (build.sh)
- [x] 启动时自动检查 GitHub - Task 7 (ProcessViewModel)
- [x] 提示用户确认后下载更新 - Task 6 (SettingsView + Task 4 UpdateBanner)
- [x] 更新文件存储在用户目录 - Task 3 (BinaryManager)

**2. 占位符检查:**
- [x] 无 TBD/TODO
- [x] 所有代码步骤包含完整实现
- [x] 所有命令步骤包含预期输出

**3. 类型一致性检查:**
- [x] BinaryVersion 在 Task 1 定义，后续任务使用一致
- [x] UpdateState 在 Task 1 定义，Task 3/4/6 使用一致
- [x] BinaryManager.shared 是单例，所有使用一致
