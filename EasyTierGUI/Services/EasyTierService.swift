import Foundation
import Combine
import Darwin

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

// MARK: - EasyTierService
// Manages the easytier CLI process lifecycle

class EasyTierService: ObservableObject {
    @Published var isRunning = false
    @Published var processOutput = ""
    @Published var logEntries: [LogEntry] = []

    private var process: Process?
    private var outputPipe: Pipe?
    private var outputObserver: AnyCancellable?
    private var logFileHandle: FileHandle?
    private var privilegedLogTimer: Timer?
    private var privilegedLogOffset: UInt64 = 0
    private var privilegedPID: Int32?

    // Read executable path from UserDefaults (set by SettingsView)
    var configuredPath: String {
        UserDefaults.standard.string(forKey: "easytierPath") ?? "/usr/local/bin"
    }

    var executablePath: String {
        resolvedBinaryPath(for: ["easytier-core", "easytier"])
    }
    var configPath: String = ""

    // MARK: - Process Control

    func start(config: EasyTierConfig) async throws {
        if isRunning {
            try await stop()
        }

        // Verify executable exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: executablePath) else {
            throw EasyTierError.executableNotFound(executablePath)
        }

        // Verify executable has execute permission
        guard fileManager.isExecutableFile(atPath: executablePath) else {
            throw EasyTierError.executableNotExecutable(executablePath)
        }

        appendOutput("[INFO] 启动 EasyTier: \(executablePath)\n")

        if getuid() != 0 {
            try startPrivileged(config: config)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = buildArguments(from: config)

        // Setup output capture
        let pipe = Pipe()
        outputPipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe

        // Launch first, then set up async reading
        try process.run()
        self.process = process
        publishRunning(true)

        // Capture output asynchronously using modern FileHandle API
        let outHandle = pipe.fileHandleForReading
        startAsyncRead(handle: outHandle)
    }

    private func buildArguments(from config: EasyTierConfig) -> [String] {
        var arguments: [String] = []

        if !config.networkName.isEmpty {
            arguments.append(contentsOf: ["--network-name", config.networkName])
        }

        if !config.networkPassword.isEmpty {
            arguments.append(contentsOf: ["--network-secret", config.networkPassword])
        }

        if !config.serverURI.isEmpty {
            arguments.append(contentsOf: ["--peers", config.serverURI])
        }

        if !config.hostname.isEmpty {
            arguments.append(contentsOf: ["--hostname", config.hostname])
        }

        if !config.useDHCP && !config.tunConfig.ipv4.isEmpty {
            arguments.append(contentsOf: ["--ipv4", config.tunConfig.ipv4])
        }

        arguments.append(contentsOf: ["--rpc-portal", "127.0.0.1:\(config.rpcPortalPort)"])
        arguments.append(contentsOf: ["--listeners", "tcp://0.0.0.0:\(config.listenPort)"])
        arguments.append(contentsOf: ["--instance-name", "etgui-\(config.id.uuidString.prefix(8))"])

        for peer in config.peers {
            arguments.append(contentsOf: ["--peers", peer])
        }

        if config.enableLatencyFirst {
            arguments.append("--latency-first")
        }

        arguments.append(contentsOf: ["--private-mode", config.enablePrivateMode ? "true" : "false"])
        arguments.append(contentsOf: ["--accept-dns", config.enableMagicDNS ? "true" : "false"])

        if config.enableMultiThread {
            arguments.append("--multi-thread")
        }

        if config.enableKCP {
            arguments.append("--enable-kcp-proxy")
        }

        if config.useDHCP {
            arguments.append("--dhcp")
        }

        return arguments
    }

    private func startPrivileged(config: EasyTierConfig) throws {
        let logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("easytier_gui_elevated.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: Data())
        }
        privilegedLogOffset = (try? FileManager.default.attributesOfItem(atPath: logURL.path)[.size] as? UInt64) ?? 0

        let command = ([executablePath] + buildArguments(from: config)).map(shellQuote).joined(separator: " ")
        let output = try PrivilegedSessionManager.shared.run(command: "\(command) >> \(shellQuote(logURL.path)) 2>&1 & echo $!")

        guard let pid = Int32(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw NSError(domain: "EasyTierGUI", code: 5, userInfo: [NSLocalizedDescriptionKey: output.isEmpty ? "无法以管理员权限启动 easytier" : output])
        }

        Thread.sleep(forTimeInterval: 0.5)
        if kill(pid, 0) != 0 && errno != EPERM {
            let logText = try? String(contentsOf: logURL, encoding: .utf8)
            let recentLog = logText?
                .components(separatedBy: .newlines)
                .suffix(20)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let errorMessage = (recentLog?.isEmpty == false) ? recentLog! : "easytier-core 启动后立即退出"
            throw NSError(domain: "EasyTierGUI", code: 6, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        process = nil
        privilegedPID = pid
        startPrivilegedLogPolling(logURL: logURL)
        publishRunning(true)
    }

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

    func stop() async throws {
        if getuid() != 0, process == nil {
            try stopPrivileged()
            privilegedPID = nil
            stopPrivilegedLogPolling()
            publishRunning(false)
            return
        }

        guard let process = process, process.isRunning else {
            publishRunning(false)
            return
        }

        process.interrupt()
        // Give it a moment to gracefully terminate
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        if process.isRunning {
            process.terminate()
        }

        self.process = nil
        self.privilegedPID = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
    }

    func forceStop() {
        if let process = process {
            process.terminate()
        }
        
        if privilegedPID != nil || getuid() != 0 {
            try? stopPrivileged()
        }
        
        self.process = nil
        self.privilegedPID = nil
        stopPrivilegedLogPolling()
        publishRunning(false)
    }

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
        if !output.isEmpty {
            appendOutput(output + "\n")
        }
    }

    // MARK: - Log Parsing

    private func parseLogEntries(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let entry = parseLogLine(line)
            logEntries.append(entry)

            // Keep max 10000 entries
            if logEntries.count > 10000 {
                logEntries.removeFirst(logEntries.count - 10000)
            }
        }
    }

    private func parseLogLine(_ line: String) -> LogEntry {
        // Typical format: [2024-01-01T12:00:00Z INFO ] message
        let pattern = #"\[([\d\-T:Z]+)\s+(\w+)\]\s+(.*)"#

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

            let timestampStr = (line as NSString).substring(with: match.range(at: 1))
            let level = (line as NSString).substring(with: match.range(at: 2))
            let message = (line as NSString).substring(with: match.range(at: 3))

            let formatter = ISO8601DateFormatter()
            let timestamp = formatter.date(from: timestampStr) ?? Date()

            return LogEntry(timestamp: timestamp, level: level, message: message)
        }

        // Fallback: treat entire line as message
        return LogEntry(timestamp: Date(), level: "INFO", message: line)
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
            self.processOutput = ""
        }
    }

    // MARK: - Peer Info (via API if available)

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
                let peers = self.decodePeers(from: data)
                completion(peers)
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
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let items: [[String: Any]]
        if let array = json as? [[String: Any]] {
            items = array
        } else if let object = json as? [String: Any] {
            if let peers = object["peers"] as? [[String: Any]] {
                items = peers
            } else if let rows = object["rows"] as? [[String: Any]] {
                items = rows
            } else if let list = object["data"] as? [[String: Any]] {
                items = list
            } else {
                items = []
            }
        } else {
            items = []
        }

        return items.map { item in
            let nodeID = stringValue(for: "id", in: item) ?? "unknown"
            let ipv4 = stringValue(for: "ipv4", in: item) ?? "-"
            let hostname = stringValue(for: "hostname", in: item) ?? "未知节点"
            let cost = stringValue(for: "cost", in: item)
            let latencyMs = doubleValue(for: "lat_ms", in: item)
            let tunnelProto = stringValue(for: "tunnel_proto", in: item)

            return PeerInfo(
                nodeID: nodeID,
                ipv4: ipv4,
                hostname: hostname,
                status: .online,
                latencyMs: latencyMs,
                cost: cost,
                tunnelProto: tunnelProto,
                location: nil
            )
        }
    }

    private func stringValue(for key: String, in dict: [String: Any]) -> String? {
        if let value = dict[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "-" ? nil : trimmed
        }
        if let value = dict[key] as? NSNumber {
            return value.stringValue
        }
        return nil
    }

    private func stringValue(for keys: [String], in dict: [String: Any]) -> String? {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.stringValue
            }
        }
        return nil
    }

    private func doubleValue(for key: String, in dict: [String: Any]) -> Double? {
        if let value = dict[key] as? NSNumber {
            return value.doubleValue
        }
        guard let text = stringValue(for: key, in: dict) else {
            return nil
        }
        return Double(text)
    }

    private func boolValue(for keys: [String], in dict: [String: Any]) -> Bool? {
        for key in keys {
            if let value = dict[key] as? Bool {
                return value
            }
            if let value = dict[key] as? String {
                switch value.lowercased() {
                case "true", "online", "connected", "1":
                    return true
                case "false", "offline", "disconnected", "0":
                    return false
                default:
                    break
                }
            }
            if let value = dict[key] as? NSNumber {
                return value.boolValue
            }
        }
        return nil
    }

    private func intValue(for keys: [String], in dict: [String: Any]) -> Int? {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            }
            if let value = dict[key] as? NSNumber {
                return value.intValue
            }
            if let value = dict[key] as? String, let int = Int(value) {
                return int
            }
        }
        return nil
    }

    private func shellQuote(_ s: String) -> String {
        if s.isEmpty { return "''" }
        let escaped = s.replacingOccurrences(of: "'", with: "'\\\\''")
        return "'\(escaped)'"
    }

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

    private func publishRunning(_ running: Bool) {
        DispatchQueue.main.async {
            self.isRunning = running
        }
    }

    private func appendOutput(_ output: String) {
        DispatchQueue.main.async {
            self.processOutput.append(output)
            self.parseLogEntries(output)
        }
    }

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
        } catch {
            return
        }
    }
}
