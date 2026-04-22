//
//  Models.swift
//  EasyTierGUI
//
//  数据模型定义
//

import Foundation
import SwiftUI

// MARK: - Network Status

/// 网络连接状态
enum NetworkStatus: String, Identifiable {
    case disconnected, connecting, connected, error

    var id: String { rawValue }

    /// 状态指示颜色
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    /// 状态描述文本
    var description: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .error: return "错误"
        }
    }
}

// MARK: - EasyTier Configuration

/// EasyTier 网络配置
struct EasyTierConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String

    // MARK: - 基础设置
    var networkName: String      // 网络名称 (组网标识)
    var networkPassword: String  // 网络密码 (组网密钥)
    var serverURI: String        // 服务器地址 (对端节点)

    // MARK: - 高级设置
    var hostname: String              // 主机名
    var enableLatencyFirst: Bool      // 延迟优先模式
    var enablePrivateMode: Bool       // 私有模式
    var enableMagicDNS: Bool          // 魔法 DNS
    var enableMultiThread: Bool       // 多线程
    var enableKCP: Bool               // KCP 代理

    // MARK: - 网络设置
    var listenPort: Int        // 监听端口
    var rpcPortalPort: Int     // RPC 管理端口
    var tunConfig: TunConfig   // TUN 设备配置
    var useDHCP: Bool          // 使用 DHCP (否则静态 IP)

    // MARK: - Initialization

    init(
        name: String = "Default",
        networkName: String = "",
        networkPassword: String = "",
        serverURI: String = "",
        hostname: String = "",
        enableLatencyFirst: Bool = false,
        enablePrivateMode: Bool = false,
        enableMagicDNS: Bool = false,
        enableMultiThread: Bool = false,
        enableKCP: Bool = false,
        listenPort: Int = 11010,
        rpcPortalPort: Int = 15888,
        tunConfig: TunConfig? = nil,
        useDHCP: Bool = true
    ) {
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
        self.tunConfig = tunConfig ?? TunConfig()
        self.useDHCP = useDHCP
    }

    // MARK: - Codable (向后兼容)

    enum CodingKeys: String, CodingKey {
        case id, name, networkName, networkPassword, serverURI, hostname
        case enableLatencyFirst, enablePrivateMode, enableMagicDNS
        case enableMultiThread, enableKCP
        case listenPort, rpcPortalPort, tunConfig, useDHCP
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
        tunConfig = try container.decodeIfPresent(TunConfig.self, forKey: .tunConfig) ?? TunConfig()
        useDHCP = try container.decodeIfPresent(Bool.self, forKey: .useDHCP) ?? true
    }
}

// MARK: - TUN Configuration

/// TUN 设备配置
struct TunConfig: Codable, Equatable {
    var ipv4: String      // IPv4 地址
    var netmask: String   // 子网掩码
    var mtu: Int          // MTU 大小

    init(ipv4: String = "", netmask: String = "255.255.255.0", mtu: Int = 1420) {
        self.ipv4 = ipv4
        self.netmask = netmask
        self.mtu = mtu
    }
}

// MARK: - Peer Info

/// 网络节点信息
struct PeerInfo: Identifiable, Equatable {
    // Use a stable identity so SwiftUI can diff peer rows across polling updates.
    var id: String { "\(nodeID)|\(ipv4)" }
    var nodeID: String        // 节点 ID
    var ipv4: String          // IPv4 地址
    var hostname: String      // 主机名
    var status: PeerStatus    // 在线状态
    var latencyMs: Double?    // 延迟 (毫秒)
    var cost: String?         // 连接方式
    var tunnelProto: String?  // 隧道协议
    var location: String?     // 地理位置

    /// 节点在线状态
    enum PeerStatus: String, Equatable {
        case online, offline
    }
}

// MARK: - Log Entry

/// 日志条目
struct LogEntry: Identifiable {
    var id = UUID()
    var timestamp: Date   // 时间戳
    var level: String     // 日志级别
    var message: String   // 日志内容

    /// 日志级别颜色
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
