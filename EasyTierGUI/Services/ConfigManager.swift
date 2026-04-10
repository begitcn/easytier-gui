import Foundation
import Combine

// MARK: - ConfigManager
// Handles persistence of EasyTier configurations

class ConfigManager: ObservableObject {
    @Published var configs: [EasyTierConfig] = []
    @Published var activeConfigIndex: Int = -1

    private let configsDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        // Store configs in ~/Library/Application Support/EasyTierGUI/
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

    func addConfig(_ config: EasyTierConfig) {
        var config = config
        config.listenPort = normalizedListenPort(for: config)
        config.rpcPortalPort = normalizedRPCPortalPort(for: config)
        configs.append(config)
        activeConfigIndex = configs.count - 1
        saveConfigs()
    }

    func updateConfig(_ config: EasyTierConfig, at index: Int) {
        guard index < configs.count else { return }
        configs[index] = config
        saveConfigs()
    }

    func deleteConfig(at index: Int) {
        guard index < configs.count else { return }
        configs.remove(at: index)

        if activeConfigIndex == index {
            activeConfigIndex = configs.isEmpty ? -1 : 0
        } else if activeConfigIndex > index {
            activeConfigIndex -= 1
        }

        saveConfigs()
    }

    func setActiveConfig(at index: Int) {
        guard index < configs.count else { return }
        activeConfigIndex = index
        saveConfigs()
    }

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
        let data = try? encoder.encode(configs)
        try? data?.write(to: configsDirectory.appendingPathComponent("configs.json"))

        // Also save active index
        let indexData = try? JSONEncoder().encode(activeConfigIndex)
        try? indexData?.write(to: configsDirectory.appendingPathComponent("active_index.json"))
    }

    private func loadConfigs() {
        let url = configsDirectory.appendingPathComponent("configs.json")
        if let data = try? Data(contentsOf: url),
           let loaded = try? decoder.decode([EasyTierConfig].self, from: data) {
            configs = loaded
        } else {
            // Create a default config
            configs = [EasyTierConfig(name: "Default")]
        }

        normalizeConfigs()

        // Load active index
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

    func exportConfig(_ config: EasyTierConfig, to url: URL) throws {
        let data = try encoder.encode(config)
        try data.write(to: url)
    }

    func importConfig(from url: URL) throws -> EasyTierConfig {
        let data = try Data(contentsOf: url)
        return try decoder.decode(EasyTierConfig.self, from: data)
    }

    /// Export all configurations to a single JSON file
    func exportAllConfigs(to url: URL) throws {
        let data = try encoder.encode(configs)
        try data.write(to: url)
    }

    /// Import multiple configurations from a JSON file
    func importConfigs(from url: URL) throws -> [EasyTierConfig] {
        let data = try Data(contentsOf: url)
        return try decoder.decode([EasyTierConfig].self, from: data)
    }

    // MARK: - Generate Config JSON for easytier CLI

    func generateCLIBuildArguments(config: EasyTierConfig) -> [String] {
        var arguments: [String] = []

        // Basic settings
        if !config.networkName.isEmpty {
            arguments.append(contentsOf: ["--network-name", config.networkName])
        }

        if !config.networkPassword.isEmpty {
            arguments.append(contentsOf: ["--network-secret", config.networkPassword])
        }

        // Server URI should be added as a peer
        if !config.serverURI.isEmpty {
            arguments.append(contentsOf: ["--peers", config.serverURI])
        }

        if !config.hostname.isEmpty {
            arguments.append(contentsOf: ["--hostname", config.hostname])
        }

        // Only add --ipv4 if not using DHCP and ipv4 is not empty
        if !config.useDHCP && !config.tunConfig.ipv4.isEmpty {
            arguments.append(contentsOf: ["--ipv4", config.tunConfig.ipv4])
        }

        arguments.append(contentsOf: ["--rpc-portal", "127.0.0.1:\(config.rpcPortalPort)"])
        arguments.append(contentsOf: ["--listeners", "tcp://0.0.0.0:\(config.listenPort)"])
        arguments.append(contentsOf: ["--instance-name", "etgui-\(config.id.uuidString.prefix(8))"])

        // Add additional peers
        for peer in config.peers {
            arguments.append(contentsOf: ["--peers", peer])
        }

        // Advanced settings
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

        // Add --dhcp flag when using DHCP mode
        if config.useDHCP {
            arguments.append("--dhcp")
        }

        // No --log-level parameter - EasyTier doesn't support it

        return arguments
    }

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
        if candidate < 1 {
            candidate = fallbackStart
        }

        while used.contains(candidate) {
            candidate += 1
        }

        used.insert(candidate)
        return candidate
    }
}
