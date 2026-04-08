import Foundation
import SwiftUI

// MARK: - Network Status
enum NetworkStatus: String, Identifiable {
    case disconnected, connecting, connected, error

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    var description: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .error: return "错误"
        }
    }
}

// MARK: - Config Model
struct EasyTierConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String

    // Basic Settings
    var networkName: String
    var networkPassword: String
    var serverURI: String

    // Advanced Settings
    var hostname: String
    var enableLatencyFirst: Bool    // 延迟优先模式
    var enablePrivateMode: Bool      // 私有模式
    var enableMagicDNS: Bool         // 魔法DNS
    var enableMultiThread: Bool      // 多线程
    var enableKCP: Bool              // KCP代理

    // Legacy settings
    var listenPort: Int
    var rpcPortalPort: Int
    var peers: [String]
    var tunConfig: TunConfig
    var useDHCP: Bool  // true = DHCP, false = 静态IP
    var logLevel: String

    init(name: String = "Default", networkName: String = "", networkPassword: String = "",
         serverURI: String = "", hostname: String = "",
         enableLatencyFirst: Bool = false, enablePrivateMode: Bool = false,
         enableMagicDNS: Bool = false, enableMultiThread: Bool = false, enableKCP: Bool = false,
         listenPort: Int = 11010, rpcPortalPort: Int = 15888, peers: [String] = [], tunConfig: TunConfig? = nil,
         useDHCP: Bool = true, logLevel: String = "info") {
        self.id = UUID()
        self.name = name
        self.networkName = networkName
        self.networkPassword = networkPassword
        self.serverURI = serverURI
        self.hostname = hostname
        self.enableLatencyFirst = enableLatencyFirst
        self.enablePrivateMode = enablePrivateMode
        self.enableMagicDNS = enableMagicDNS
        self.enableMultiThread = enableMultiThread
        self.enableKCP = enableKCP
        self.listenPort = listenPort
        self.rpcPortalPort = rpcPortalPort
        self.peers = peers
        self.tunConfig = tunConfig ?? TunConfig()
        self.useDHCP = useDHCP
        self.logLevel = logLevel
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case networkName
        case networkPassword
        case serverURI
        case hostname
        case enableLatencyFirst
        case enablePrivateMode
        case enableMagicDNS
        case enableMultiThread
        case enableKCP
        case listenPort
        case rpcPortalPort
        case peers
        case tunConfig
        case useDHCP
        case logLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        networkName = try container.decodeIfPresent(String.self, forKey: .networkName) ?? ""
        networkPassword = try container.decodeIfPresent(String.self, forKey: .networkPassword) ?? ""
        serverURI = try container.decodeIfPresent(String.self, forKey: .serverURI) ?? ""
        hostname = try container.decodeIfPresent(String.self, forKey: .hostname) ?? ""
        enableLatencyFirst = try container.decodeIfPresent(Bool.self, forKey: .enableLatencyFirst) ?? false
        enablePrivateMode = try container.decodeIfPresent(Bool.self, forKey: .enablePrivateMode) ?? false
        enableMagicDNS = try container.decodeIfPresent(Bool.self, forKey: .enableMagicDNS) ?? false
        enableMultiThread = try container.decodeIfPresent(Bool.self, forKey: .enableMultiThread) ?? false
        enableKCP = try container.decodeIfPresent(Bool.self, forKey: .enableKCP) ?? false
        listenPort = try container.decodeIfPresent(Int.self, forKey: .listenPort) ?? 11010
        rpcPortalPort = try container.decodeIfPresent(Int.self, forKey: .rpcPortalPort) ?? 15888
        peers = try container.decodeIfPresent([String].self, forKey: .peers) ?? []
        tunConfig = try container.decodeIfPresent(TunConfig.self, forKey: .tunConfig) ?? TunConfig()
        useDHCP = try container.decodeIfPresent(Bool.self, forKey: .useDHCP) ?? true
        logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel) ?? "info"
    }
}

struct TunConfig: Codable, Equatable {
    var ipv4: String
    var netmask: String
    var mtu: Int

    init(ipv4: String = "", netmask: String = "255.255.255.0", mtu: Int = 1420) {
        self.ipv4 = ipv4
        self.netmask = netmask
        self.mtu = mtu
    }
}

// MARK: - Peer Info
struct PeerInfo: Identifiable, Equatable {
    var id = UUID()
    var nodeID: String
    var ipv4: String
    var hostname: String
    var status: PeerStatus
    var latencyMs: Double?
    var cost: String?
    var tunnelProto: String?
    var location: String?

    enum PeerStatus: String, Equatable {
        case online, offline, connecting
    }
}

// MARK: - Log Entry
struct LogEntry: Identifiable {
    var id = UUID()
    var timestamp: Date
    var level: String
    var message: String

    var levelColor: Color {
        switch level.lowercased() {
        case "error", "err": return .red
        case "warn", "warning": return .orange
        case "info": return .blue
        case "debug": return .gray
        default: return .primary
        }
    }
}
