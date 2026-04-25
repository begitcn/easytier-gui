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

    func isAuthorizedCached() -> Bool {
        PrivilegedExecutor.isAuthorizedCached()
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
    @Published var logEntries: [LogEntry] = []

    // MARK: - Memory Management

    private let maxLogEntries = 100       // 最大日志条数
    private let maxLogMessageLength = 2000

    // MARK: - Log Update Throttling

    private var logUpdateTask: Task<Void, Never>?
    private let logUpdateThrottleInterval: TimeInterval = 0.1 // 100ms
    private var pendingLogLines: [String] = []
    private let pendingLogLock = NSLock()

    // MARK: - Private Properties

    private var process: Process?
    private var outputPipe: Pipe?
    private var privilegedLogTimer: Timer?
    private var privilegedLogOffset: UInt64 = 0
    private var privilegedPID: Int32?
    private var privilegedLogURL: URL?
    private let privilegedLogReadQueue = DispatchQueue(label: "EasyTierGUI.PrivilegedLogRead", qos: .utility)
    private let peerFetchQueue = DispatchQueue(label: "EasyTierGUI.PeerFetch", qos: .utility)
    private let peerFetchStateQueue = DispatchQueue(label: "EasyTierGUI.PeerFetchState")
    private var isPeerFetchInProgress = false
    private let peerFetchTimeout: TimeInterval = 4.0
    private var pendingLogFragment = ""

    private static let logLineRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"\[([\d\-T:Z]+)\s+(\w+)\]\s+(.*)"#
    )
    private static let logDateFormatter = ISO8601DateFormatter()

    /// 解析后的可执行文件路径
    var executablePath: String {
        BinaryManager.resolveBinaryPath(for: .core).path
    }

    /// Toast notification callback - set by NetworkRuntime to show crash notifications
    var showToast: ((String) -> Void)?

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
            // Run privileged execution on a background thread to avoid blocking main thread
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try self.startPrivileged(config: config)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
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

        // Set termination handler BEFORE run() to detect crashes
        process.terminationHandler = { [weak self] process in
            let exitCode = process.terminationStatus
            let reason = process.terminationReason

            Task { @MainActor [weak self] in
                await self?.handleProcessTermination(exitCode: exitCode, reason: reason)
            }
        }

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
            // 总是尝试停止特权进程，即使 shouldStopPrivilegedProcess 返回 false
            // 因为进程可能仍在运行（端口占用问题）
            if let pid = privilegedPID {
                // 先检查进程是否还在运行
                let isRunning = kill(pid, 0) == 0 || errno == EPERM
                if isRunning {
                    try stopPrivileged()
                }
            }
            privilegedPID = nil
            privilegedLogURL = nil
            stopPrivilegedLogPolling()
            publishRunning(false)
#if DEBUG
            verifyCleanup()
#endif
            return
        }

        // 停止普通进程
        guard let process = process, process.isRunning else {
            self.process = nil
            publishRunning(false)
#if DEBUG
            verifyCleanup()
#endif
            return
        }

        process.interrupt()
        try await Task.sleep(nanoseconds: 500_000_000) // 等待 0.5s

        if process.isRunning {
            process.terminate()
        }

        self.process = nil
        privilegedPID = nil
        privilegedLogURL = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
#if DEBUG
        verifyCleanup()
#endif
    }

    /// 强制停止进程
    func forceStop(allowPrivilegePrompt: Bool = true) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        if let process, process.isRunning {
            process.interrupt()
            process.terminate()
        }

        if shouldStopPrivilegedProcess {
            if allowPrivilegePrompt || PrivilegedSessionManager.shared.isAuthorizedCached() {
                try? stopPrivileged()
            } else if let pid = privilegedPID {
                // D-03: Graceful termination with timeout (SIGTERM → wait 3s → SIGKILL)
                // Step 1: Try graceful termination with SIGTERM
                kill(pid, SIGTERM)

                // Step 2: Wait up to 3 seconds for graceful exit
                var waited = 0
                while waited < 30 {  // 30 * 0.1s = 3 seconds
                    usleep(100_000)  // 100ms
                    if kill(pid, 0) != 0 {
                        // Process exited gracefully
                        break
                    }
                    waited += 1
                }

                // Step 3: Force kill if still running
                if kill(pid, 0) == 0 {
                    kill(pid, SIGKILL)
                }
            }
        }

        process = nil
        privilegedPID = nil
        privilegedLogURL = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
#if DEBUG
        verifyCleanup()
#endif
    }
    @MainActor
    private func handleProcessTermination(exitCode: Int32, reason: Process.TerminationReason) async {
        // Log based on exit reason
        if exitCode == 0 {
            log("Process exited normally", level: .info)
        } else if reason == .uncaughtSignal {
            log("Process terminated by signal: \(exitCode)", level: .warning)
        } else {
            log("Process crashed with exit code: \(exitCode)", level: .error)
            // Notify user via Toast
            showToast?("EasyTier 核心意外退出，请检查日志")
        }

        // Update status
        isRunning = false
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

    /// 清理所有遗留的 easytier-core/easytier-cli 进程（应用启动和退出时调用）
    static func cleanupOrphanedProcesses() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // 只在非 root 用户下尝试清理，root 用户可以直接 kill
                guard getuid() != 0 else {
                    // root 用户直接用 pkill 清理
                    try? runCleanupCommandAsRoot()
                    continuation.resume()
                    return
                }

                // 检查是否有缓存的授权，避免弹出密码框
                guard PrivilegedSessionManager.shared.isAuthorizedCached() else {
                    // 没有授权缓存，尝试用普通用户权限清理可能存在的非特权进程
                    try? runCleanupCommandWithoutPrivilege()
                    continuation.resume()
                    return
                }

                // 有授权缓存，可以清理特权进程
                try? runCleanupCommandWithPrivilege()
                continuation.resume()
            }
        }
    }

    private static func runCleanupCommandWithoutPrivilege() throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "easytier-(core|cli)"]
        try? task.run()
        task.waitUntilExit()
    }

    private static func runCleanupCommandWithPrivilege() throws {
        _ = try? PrivilegedSessionManager.shared.run(
            command: "pkill -9 -f 'easytier-core' 2>/dev/null || true; pkill -9 -f 'easytier-cli' 2>/dev/null || true; pkill -9 -f 'etgui-' 2>/dev/null || true; echo cleaned",
            timeout: 3
        )
    }

    private static func runCleanupCommandAsRoot() throws {
        // root 用户直接运行 pkill，不需要特权授权
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-9", "-f", "easytier-(core|cli)"]
        try? task.run()
        task.waitUntilExit()
    }

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
        privilegedLogURL = logURL
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
                    self.parseLogEntries(output)
                }
            }
        }
    }

    /// 解析日志条目
    private func parseLogEntries(_ text: String) {
        guard isLogMonitoringEnabled else {
            pendingLogFragment = ""
            return
        }

        let combined = pendingLogFragment + text
        let hasTrailingNewline = combined.unicodeScalars.last.map { CharacterSet.newlines.contains($0) } ?? false
        var lines = combined.components(separatedBy: .newlines)
        if !hasTrailingNewline, !lines.isEmpty {
            pendingLogFragment = lines.removeLast()
        } else {
            pendingLogFragment = ""
        }

        // Add lines to pending queue
        pendingLogLock.lock()
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            pendingLogLines.append(line)
        }
        pendingLogLock.unlock()

        // Throttle UI update
        scheduleLogUpdate()
    }

    private func scheduleLogUpdate() {
        logUpdateTask?.cancel()
        logUpdateTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(logUpdateThrottleInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.flushPendingLogs()
            }
        }
    }

    @MainActor
    private func flushPendingLogs() {
        pendingLogLock.lock()
        let linesToProcess = pendingLogLines
        pendingLogLines.removeAll()
        pendingLogLock.unlock()

        for line in linesToProcess {
            logEntries.append(parseLogLine(line))
        }

        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }

    /// 解析单行日志
    private func parseLogLine(_ line: String) -> LogEntry {
        if let regex = Self.logLineRegex,
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let timestampStr = (line as NSString).substring(with: match.range(at: 1))
            let level = (line as NSString).substring(with: match.range(at: 2))
            let message = clippedLogMessage((line as NSString).substring(with: match.range(at: 3)))
            let timestamp = Self.logDateFormatter.date(from: timestampStr) ?? Date()
            return LogEntry(timestamp: timestamp, level: level, message: message)
        }
        return LogEntry(timestamp: Date(), level: "INFO", message: clippedLogMessage(line))
    }

    /// 清空日志
    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
            self.pendingLogFragment = ""
        }
    }

    func setLogMonitoringEnabled(_ enabled: Bool) {
        if enabled {
            if getuid() != 0, process == nil, shouldStopPrivilegedProcess, let logURL = privilegedLogURL {
                startPrivilegedLogPolling(logURL: logURL)
            }
            return
        }

        stopPrivilegedLogPolling()
        clearLogs()
    }

    // MARK: - Peer Info

    /// 获取节点列表
    func fetchPeers(rpcPortalPort: Int, completion: @escaping ([PeerInfo]) -> Void) {
        guard let cliPath = easytierCLIPath() else {
            completion([])
            return
        }

        let shouldStartFetch = peerFetchStateQueue.sync { () -> Bool in
            if isPeerFetchInProgress { return false }
            isPeerFetchInProgress = true
            return true
        }

        guard shouldStartFetch else {
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: cliPath)
        task.arguments = ["-p", "127.0.0.1:\(rpcPortalPort)", "-o", "json", "peer", "list"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        peerFetchQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try task.run()

                let waitGroup = DispatchGroup()
                waitGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    task.waitUntilExit()
                    waitGroup.leave()
                }

                if waitGroup.wait(timeout: .now() + self.peerFetchTimeout) == .timedOut {
                    task.terminate()
                    _ = waitGroup.wait(timeout: .now() + 1.0)
                    self.finishPeerFetch([], completion: completion)
                    // Clean up pipe
                    pipe.fileHandleForReading.readabilityHandler = nil
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                self.finishPeerFetch(self.decodePeers(from: data), completion: completion)
                // Clean up pipe
                pipe.fileHandleForReading.readabilityHandler = nil
            } catch {
                self.finishPeerFetch([], completion: completion)
                // Clean up pipe
                pipe.fileHandleForReading.readabilityHandler = nil
            }
        }
    }

    private func easytierCLIPath() -> String? {
        let path = BinaryManager.resolveBinaryPath(for: .cli)
        return FileManager.default.isExecutableFile(atPath: path.path) ? path.path : nil
    }

    private func decodePeers(from data: Data) -> [PeerInfo] {
        let decoder = JSONDecoder()
        let peerItems: [PeerDTO]

        if let array = try? decoder.decode([PeerDTO].self, from: data) {
            peerItems = array
        } else if let payload = try? decoder.decode(PeerPayload.self, from: data) {
            peerItems = payload.peers ?? payload.rows ?? payload.data ?? []
        } else {
            return []
        }

        return peerItems.map { item in
            PeerInfo(
                nodeID: item.id ?? "unknown",
                ipv4: item.ipv4 ?? "-",
                hostname: item.hostname ?? "未知节点",
                status: .online,
                latencyMs: item.latencyMs,
                cost: item.cost,
                tunnelProto: item.tunnelProto,
                location: nil
            )
        }
    }

    // MARK: - Helpers

    private func shellQuote(_ s: String) -> String {
        if s.isEmpty { return "''" }
        return "'\(s.replacingOccurrences(of: "'", with: "'\\\\''"))'"
    }

    private func publishRunning(_ running: Bool) {
        DispatchQueue.main.async { self.isRunning = running }
    }

    private func log(_ message: String, level: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp) \(level.uppercased())] \(message)"
        appendOutput(formatted + "\n")
    }

    /// 日志级别
    private enum LogLevel {
        case info, warning, error
    }

    private func log(_ message: String, level: LogLevel) {
        switch level {
        case .info:
            log(message, level: "INFO")
        case .warning:
            log(message, level: "WARNING")
        case .error:
            log(message, level: "ERROR")
        }
    }

    private func appendOutput(_ output: String) {
        DispatchQueue.main.async {
            self.parseLogEntries(output)
        }
    }

    private var isLogMonitoringEnabled: Bool {
        UserDefaults.standard.bool(forKey: "enableLogMonitoring")
    }

    private func clippedLogMessage(_ message: String) -> String {
        guard message.count > maxLogMessageLength else { return message }
        let prefix = message.prefix(maxLogMessageLength)
        return "\(prefix)... [truncated]"
    }

    private func finishPeerFetch(_ peers: [PeerInfo], completion: @escaping ([PeerInfo]) -> Void) {
        peerFetchStateQueue.async {
            self.isPeerFetchInProgress = false
            completion(peers)
        }
    }

    private var shouldStopPrivilegedProcess: Bool {
        guard getuid() != 0 else { return false }
        guard let pid = privilegedPID else { return false }
        if kill(pid, 0) == 0 || errno == EPERM {
            return true
        }
        privilegedPID = nil
        return false
    }

    // MARK: - Deinitialization

    deinit {
        // Clean up timer if still running
        privilegedLogTimer?.invalidate()
        privilegedLogTimer = nil
#if DEBUG
        print("[DEBUG] EasyTierService deinit - \(privilegedPID != nil ? "privileged" : "normal")")
#endif
    }

#if DEBUG
    /// 验证资源清理（调试用）
    private func verifyCleanup() {
        assert(outputPipe == nil, "outputPipe not cleaned up!")
        assert(process == nil, "process not cleaned up!")
        print("[DEBUG] EasyTierService cleanup verified - privilegedPID: \(privilegedPID ?? -1)")
    }
#endif

    // MARK: - Privileged Log Polling

    private func startPrivilegedLogPolling(logURL: URL) {
        guard isLogMonitoringEnabled else { return }
        stopPrivilegedLogPolling()
        DispatchQueue.main.async {
            self.privilegedLogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                guard self.isLogMonitoringEnabled else {
                    self.stopPrivilegedLogPolling()
                    return
                }
                self.privilegedLogReadQueue.async { [weak self] in
                    self?.readPrivilegedLogIncrement(from: logURL)
                }
            }
        }
        privilegedLogReadQueue.async { [weak self] in
            self?.readPrivilegedLogIncrement(from: logURL)
        }
    }

    private func stopPrivilegedLogPolling() {
        DispatchQueue.main.async {
            self.privilegedLogTimer?.invalidate()
            self.privilegedLogTimer = nil
        }
        privilegedLogReadQueue.async {
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

private struct PeerPayload: Decodable {
    let peers: [PeerDTO]?
    let rows: [PeerDTO]?
    let data: [PeerDTO]?
}

private struct PeerDTO: Decodable {
    let id: String?
    let ipv4: String?
    let hostname: String?
    let latencyMs: Double?
    let cost: String?
    let tunnelProto: String?

    enum CodingKeys: String, CodingKey {
        case id, ipv4, hostname, cost
        case latencyMs = "lat_ms"
        case tunnelProto = "tunnel_proto"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyString(forKey: .id)
        ipv4 = container.decodeLossyString(forKey: .ipv4)
        hostname = container.decodeLossyString(forKey: .hostname)
        latencyMs = container.decodeLossyDouble(forKey: .latencyMs)
        cost = container.decodeLossyString(forKey: .cost)
        tunnelProto = container.decodeLossyString(forKey: .tunnelProto)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyString(forKey key: K) -> String? {
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed.isEmpty || trimmed == "-") ? nil : trimmed
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }

    func decodeLossyDouble(forKey key: K) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(intValue)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }
}
