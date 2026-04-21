//
//  EasyTierService.swift
//  EasyTierGUI
//
//  EasyTier 进程管理服务
//  负责 easytier-core 进程的生命周期管理和输出解析
//

import Foundation
import Combine
import Darwin

// MARK: - Privileged Session Manager

/// 权限会话管理器 - 处理管理员权限
final class PrivilegedSessionManager {
    static let shared = PrivilegedSessionManager()

    func ensureAuthorized() throws {
        try PrivilegedExecutor.ensureAuthorized()
    }

    func run(command: String, timeout: TimeInterval = 10) throws -> String {
        _ = timeout
        return try PrivilegedExecutor.runCommand(command)
    }
}

// MARK: - Errors

/// EasyTier 错误类型
enum EasyTierError: LocalizedError {
    case executableNotFound(String)
    case executableNotExecutable(String)
    case requiresPrivileges

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "可执行文件不存在: \(path)\n请在设置中选择正确的 easytier-core 可执行文件路径"
        case .executableNotExecutable(let path):
            return "文件不可执行: \(path)\n请在终端运行: chmod +x \"\(path)\""
        case .requiresPrivileges:
            return "当前会话尚未完成管理员授权。\n请在应用启动时完成授权，之后连接和断开无需再次输入密码。"
        }
    }
}

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

    /// 配置的可执行文件路径
    var configuredPath: String {
        UserDefaults.standard.string(forKey: "easytierPath") ?? "/usr/local/bin"
    }

    /// 解析后的可执行文件路径
    var executablePath: String {
        resolvedBinaryPath(for: ["easytier-core", "easytier"])
    }

    // MARK: - Process Control

    /// 启动 EasyTier 进程
    func start(config: EasyTierConfig) async throws {
        if isRunning {
            try await stop()
        }

        // 验证可执行文件
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: executablePath) else {
            throw EasyTierError.executableNotFound(executablePath)
        }
        guard fileManager.isExecutableFile(atPath: executablePath) else {
            throw EasyTierError.executableNotExecutable(executablePath)
        }

        appendOutput("[INFO] 启动 EasyTier: \(executablePath)\n")

        // 非 root 用户使用特权模式启动
        if getuid() != 0 {
            try startPrivileged(config: config)
            return
        }

        // 直接启动进程 (已具有 root 权限)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = buildArguments(from: config)

        let pipe = Pipe()
        outputPipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        self.process = process
        publishRunning(true)

        startAsyncRead(handle: pipe.fileHandleForReading)
    }

    /// 停止 EasyTier 进程
    func stop() async throws {
        // 清理输出管道
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        // 停止特权进程
        if getuid() != 0, process == nil {
            try stopPrivileged()
            privilegedPID = nil
            stopPrivilegedLogPolling()
            publishRunning(false)
            return
        }

        // 停止普通进程
        guard let process = process, process.isRunning else {
            self.process = nil
            publishRunning(false)
            return
        }

        process.interrupt()
        try await Task.sleep(nanoseconds: 500_000_000) // 等待 0.5s

        if process.isRunning {
            process.terminate()
        }

        self.process = nil
        privilegedPID = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
    }

    /// 强制停止进程
    func forceStop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        process?.terminate()

        if privilegedPID != nil || getuid() != 0 {
            try? stopPrivileged()
        }

        process = nil
        privilegedPID = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
    }

    // MARK: - Argument Building

    /// 构建命令行参数
    private func buildArguments(from config: EasyTierConfig) -> [String] {
        var args: [String] = []

        // 基础参数
        if !config.networkName.isEmpty {
            args.append(contentsOf: ["--network-name", config.networkName])
        }
        if !config.networkPassword.isEmpty {
            args.append(contentsOf: ["--network-secret", config.networkPassword])
        }
        if !config.serverURI.isEmpty {
            args.append(contentsOf: ["--peers", config.serverURI])
        }
        if !config.hostname.isEmpty {
            args.append(contentsOf: ["--hostname", config.hostname])
        }

        // IP 配置
        if !config.useDHCP && !config.tunConfig.ipv4.isEmpty {
            args.append(contentsOf: ["--ipv4", config.tunConfig.ipv4])
        }

        // 端口配置
        args.append(contentsOf: ["--rpc-portal", "127.0.0.1:\(config.rpcPortalPort)"])
        args.append(contentsOf: ["--listeners", "tcp://0.0.0.0:\(config.listenPort)"])
        args.append(contentsOf: ["--instance-name", "etgui-\(config.id.uuidString.prefix(8))"])

        // 高级选项
        if config.enableLatencyFirst { args.append("--latency-first") }
        args.append(contentsOf: ["--private-mode", config.enablePrivateMode ? "true" : "false"])
        args.append(contentsOf: ["--accept-dns", config.enableMagicDNS ? "true" : "false"])
        if config.enableMultiThread { args.append("--multi-thread") }
        if config.enableKCP { args.append("--enable-kcp-proxy") }
        if config.useDHCP { args.append("--dhcp") }

        return args
    }

    // MARK: - Privileged Execution

    /// 以特权模式启动进程
    private func startPrivileged(config: EasyTierConfig) throws {
        let logURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("easytier_gui_elevated.log")

        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: Data())
        }
        privilegedLogOffset = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? UInt64) ?? 0

        let command = ([executablePath] + buildArguments(from: config))
            .map(shellQuote).joined(separator: " ")
        let output = try PrivilegedSessionManager.shared.run(
            command: "\(command) >> \(shellQuote(logURL.path)) 2>&1 & echo $!"
        )

        guard let pid = Int32(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "EasyTierGUI", code: 5,
                userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "无法以管理员权限启动 easytier" : output])
        }

        Thread.sleep(forTimeInterval: 0.5)
        if kill(pid, 0) != 0 && errno != EPERM {
            let logText = try? String(contentsOf: logURL, encoding: .utf8)
            let recentLog = logText?.components(separatedBy: .newlines).suffix(20)
                .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "EasyTierGUI", code: 6,
                userInfo: [NSLocalizedDescriptionKey: (recentLog?.isEmpty == false) ? recentLog! : "easytier-core 启动后立即退出"])
        }

        process = nil
        privilegedPID = pid
        startPrivilegedLogPolling(logURL: logURL)
        publishRunning(true)
    }

    /// 停止特权进程
    private func stopPrivileged() throws {
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        var commands: [String] = []

        if let pid = privilegedPID {
            commands.append("kill -TERM \(pid) >/dev/null 2>&1 || true")
            commands.append("sleep 1")
            commands.append("kill -0 \(pid) >/dev/null 2>&1 && kill -KILL \(pid) >/dev/null 2>&1 || true")
        }

        commands.append("pkill -x \(shellQuote(executableName)) >/dev/null 2>&1 || true")
        commands.append("pkill -f \(shellQuote(executablePath)) >/dev/null 2>&1 || true")
        commands.append("echo stopped")

        let output = try PrivilegedSessionManager.shared.run(command: commands.joined(separator: "; "), timeout: 5)
        if !output.isEmpty { appendOutput(output + "\n") }
    }

    // MARK: - Output Handling

    /// 启动异步读取
    private func startAsyncRead(handle: FileHandle) {
        handle.readabilityHandler = { [weak self] currentHandle in
            guard let self = self else {
                currentHandle.readabilityHandler = nil
                return
            }
            let data = currentHandle.availableData
            guard !data.isEmpty else {
                currentHandle.readabilityHandler = nil
                return
            }
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.processOutput.append(output)
                    self.parseLogEntries(output)
                }
            }
        }
    }

    /// 解析日志条目
    private func parseLogEntries(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            logEntries.append(parseLogLine(line))
        }
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }

    /// 解析单行日志
    private func parseLogLine(_ line: String) -> LogEntry {
        let pattern = #"\[([\d\-T:Z]+)\s+(\w+)\]\s+(.*)"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let timestampStr = (line as NSString).substring(with: match.range(at: 1))
            let level = (line as NSString).substring(with: match.range(at: 2))
            let message = (line as NSString).substring(with: match.range(at: 3))
            let timestamp = ISO8601DateFormatter().date(from: timestampStr) ?? Date()
            return LogEntry(timestamp: timestamp, level: level, message: message)
        }
        return LogEntry(timestamp: Date(), level: "INFO", message: line)
    }

    /// 清理输出缓冲
    private func trimProcessOutput() {
        if processOutput.count > maxOutputLength {
            processOutput.removeFirst(processOutput.count - maxOutputLength)
        }
    }

    /// 清空日志
    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
            self.processOutput = ""
        }
    }

    // MARK: - Peer Info

    /// 获取节点列表
    func fetchPeers(rpcPortalPort: Int, completion: @escaping ([PeerInfo]) -> Void) {
        guard let cliPath = easytierCLIPath() else {
            completion([])
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["-p", "127.0.0.1:\(rpcPortalPort)", "-o", "json", "peer", "list"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        DispatchQueue.global(qos: .utility).async {
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                completion(self.decodePeers(from: data))
            } catch {
                completion([])
            }
        }
    }

    private func easytierCLIPath() -> String? {
        let path = resolvedBinaryPath(for: ["easytier-cli"])
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    private func decodePeers(from data: Data) -> [PeerInfo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }

        let items: [[String: Any]]
        if let array = json as? [[String: Any]] {
            items = array
        } else if let object = json as? [String: Any] {
            items = object["peers"] as? [[String: Any]]
                ?? object["rows"] as? [[String: Any]]
                ?? object["data"] as? [[String: Any]]
                ?? []
        } else {
            items = []
        }

        return items.map { item in
            PeerInfo(
                nodeID: stringValue(for: "id", in: item) ?? "unknown",
                ipv4: stringValue(for: "ipv4", in: item) ?? "-",
                hostname: stringValue(for: "hostname", in: item) ?? "未知节点",
                status: .online,
                latencyMs: doubleValue(for: "lat_ms", in: item),
                cost: stringValue(for: "cost", in: item),
                tunnelProto: stringValue(for: "tunnel_proto", in: item),
                location: nil
            )
        }
    }

    // MARK: - Helpers

    private func resolvedBinaryPath(for names: [String]) -> String {
        let configuredURL = URL(fileURLWithPath: configuredPath)
        var searchDirectories: [URL] = []

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: configuredURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            searchDirectories.append(configuredURL)
        } else {
            let fileName = configuredURL.lastPathComponent
            if names.contains(fileName), FileManager.default.isExecutableFile(atPath: configuredURL.path) {
                return configuredURL.path
            }
            searchDirectories.append(configuredURL.deletingLastPathComponent())
        }

        searchDirectories.append(URL(fileURLWithPath: "/usr/local/bin"))
        searchDirectories.append(URL(fileURLWithPath: "/opt/homebrew/bin"))

        for directory in searchDirectories {
            for name in names {
                let candidate = directory.appendingPathComponent(name).path
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }
        return configuredURL.path
    }

    private func shellQuote(_ s: String) -> String {
        if s.isEmpty { return "''" }
        return "'\(s.replacingOccurrences(of: "'", with: "'\\\\''"))'"
    }

    private func stringValue(for key: String, in dict: [String: Any]) -> String? {
        if let value = dict[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed.isEmpty || trimmed == "-") ? nil : trimmed
        }
        if let value = dict[key] as? NSNumber { return value.stringValue }
        return nil
    }

    private func doubleValue(for key: String, in dict: [String: Any]) -> Double? {
        if let value = dict[key] as? NSNumber { return value.doubleValue }
        guard let text = stringValue(for: key, in: dict) else { return nil }
        return Double(text)
    }

    private func publishRunning(_ running: Bool) {
        DispatchQueue.main.async { self.isRunning = running }
    }

    private func appendOutput(_ output: String) {
        DispatchQueue.main.async {
            self.processOutput.append(output)
            self.trimProcessOutput()
            self.parseLogEntries(output)
        }
    }

    // MARK: - Privileged Log Polling

    private func startPrivilegedLogPolling(logURL: URL) {
        stopPrivilegedLogPolling()
        DispatchQueue.main.async {
            self.privilegedLogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.readPrivilegedLogIncrement(from: logURL)
            }
        }
        readPrivilegedLogIncrement(from: logURL)
    }

    private func stopPrivilegedLogPolling() {
        DispatchQueue.main.async {
            self.privilegedLogTimer?.invalidate()
            self.privilegedLogTimer = nil
            self.privilegedLogOffset = 0
        }
    }

    private func readPrivilegedLogIncrement(from logURL: URL) {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: privilegedLogOffset)
            let data = try handle.readToEnd() ?? Data()
            privilegedLogOffset += UInt64(data.count)
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                appendOutput(output)
            }
        } catch { return }
    }
}
