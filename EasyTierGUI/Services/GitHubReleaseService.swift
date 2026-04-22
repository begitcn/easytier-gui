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
    private let githubReleasesBase = "https://github.com/EasyTier/EasyTier/releases"
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
            if elapsed < 300 {
                return cached
            }
        }

        do {
            let release = try await fetchLatestReleaseWithoutAPI()
            cachedLatestRelease = release
            lastCheckTime = Date()
            return release
        } catch {
            // 回退到 GitHub API，兼容特殊网络环境或重定向异常
            let release = try await fetchLatestReleaseFromAPI()
            cachedLatestRelease = release
            lastCheckTime = Date()
            return release
        }
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
        let chunkSize = 64 * 1024
        let progressStepBytes: Int64 = 256 * 1024
        var bytesSinceLastProgress: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(chunkSize)

        // 创建文件句柄
        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: destination)

        defer {
            try? fileHandle.close()
        }

        // 流式写入
        for try await byte in asyncBytes {
            buffer.append(byte)
            receivedLength += 1
            bytesSinceLastProgress += 1

            if buffer.count >= chunkSize {
                try fileHandle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if expectedLength > 0, (bytesSinceLastProgress >= progressStepBytes || receivedLength == expectedLength) {
                let progressValue = Double(receivedLength) / Double(expectedLength)
                await MainActor.run {
                    progress(progressValue)
                }
                bytesSinceLastProgress = 0
            }
        }

        if !buffer.isEmpty {
            try fileHandle.write(contentsOf: buffer)
        }

        await MainActor.run {
            progress(1.0)
        }

        return destination
    }

    // MARK: - Private Methods

    private func fetchLatestReleaseWithoutAPI() async throws -> BinaryVersion {
        let latestURL = URL(string: "\(githubReleasesBase)/latest")!
        var request = URLRequest(url: latestURL)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (_, response) = try await session.data(for: request)
        guard let finalURL = response.url else {
            throw GitHubError.invalidResponse
        }

        let tagName = finalURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tagName.isEmpty,
              finalURL.absoluteString.contains("/releases/tag/") else {
            throw GitHubError.releaseNotFound
        }

        let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
        let downloadURL = try await resolveDownloadURL(tagName: tagName)

        return BinaryVersion(
            version: version,
            tagName: tagName,
            releaseNotes: nil,
            downloadURL: downloadURL,
            publishedAt: Date()
        )
    }

    private func fetchLatestReleaseFromAPI() async throws -> BinaryVersion {
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

        return try parseRelease(data)
    }

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

        guard let downloadURL = findDownloadURL(for: assets) else {
            throw GitHubError.assetNotFound
        }

        return BinaryVersion(
            version: version,
            tagName: tagName,
            releaseNotes: releaseNotes,
            downloadURL: downloadURL,
            publishedAt: publishedAt
        )
    }

    private func findDownloadURL(for assets: [[String: Any]]) -> URL? {
        for asset in assets {
            guard let name = asset["name"] as? String,
                  let urlString = asset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                continue
            }

            // 兼容两种命名：
            // - easytier-macos-aarch64-vX.Y.Z.zip / easytier-macos-x86_64-vX.Y.Z.zip
            // - easytier-apple-darwin-arm64.zip / easytier-apple-darwin-x86_64.zip
            if candidateAssetNamePatterns().contains(where: { name.contains($0) }) && name.hasSuffix(".zip") {
                return url
            }
        }

        return nil
    }

    private func resolveDownloadURL(tagName: String) async throws -> URL {
        let candidates = candidateDownloadURLs(tagName: tagName)

        for candidate in candidates {
            if try await urlExists(candidate) {
                return candidate
            }
        }

        throw GitHubError.assetNotFound
    }

    private func candidateDownloadURLs(tagName: String) -> [URL] {
        let prefix = "\(githubReleasesBase)/download/\(tagName)/"
        return candidateAssetNames(tagName: tagName).compactMap { URL(string: prefix + $0) }
    }

    private func candidateAssetNames(tagName: String) -> [String] {
        let normalizedTag = tagName.hasPrefix("v") ? tagName : "v\(tagName)"

        #if arch(arm64)
        return [
            "easytier-macos-aarch64-\(normalizedTag).zip",
            "easytier-macos-arm64-\(normalizedTag).zip",
            "easytier-apple-darwin-arm64.zip"
        ]
        #elseif arch(x86_64)
        return [
            "easytier-macos-x86_64-\(normalizedTag).zip",
            "easytier-apple-darwin-x86_64.zip"
        ]
        #else
        return [
            "easytier-apple-darwin.zip"
        ]
        #endif
    }

    private func candidateAssetNamePatterns() -> [String] {
        #if arch(arm64)
        return ["macos-aarch64", "macos-arm64", "apple-darwin-arm64"]
        #elseif arch(x86_64)
        return ["macos-x86_64", "apple-darwin-x86_64"]
        #else
        return ["apple-darwin"]
        #endif
    }

    private func urlExists(_ url: URL) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        return (200...399).contains(httpResponse.statusCode)
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
