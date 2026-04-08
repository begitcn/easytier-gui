import SwiftUI
import AppKit

// MARK: - PeersView
// Displays connected peers/nodes in the network

struct PeersView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var searchText = ""
    @State private var sortKey: SortKey = .hostname

    private var selectedConfigIndex: Binding<Int> {
        Binding(
            get: { max(vm.configManager.activeConfigIndex, 0) },
            set: { vm.configManager.setActiveConfig(at: $0) }
        )
    }

    enum SortKey: String, CaseIterable {
        case hostname, ipv4, latency, cost, status

        var label: String {
            switch self {
            case .hostname: return "主机名"
            case .ipv4: return "IP 地址"
            case .latency: return "延迟"
            case .cost: return "连接方式"
            case .status: return "状态"
            }
        }
    }

    var filteredPeers: [PeerInfo] {
        var result = vm.peers

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { peer in
                peer.hostname.lowercased().contains(query) ||
                peer.ipv4.contains(query) ||
                peer.nodeID.lowercased().contains(query) ||
                (peer.cost?.lowercased().contains(query) ?? false)
            }
        }

        // Sort
        result.sort { a, b in
            switch sortKey {
            case .hostname: return a.hostname < b.hostname
            case .ipv4: return a.ipv4 < b.ipv4
            case .latency: return (a.latencyMs ?? Double.greatestFiniteMagnitude) < (b.latencyMs ?? Double.greatestFiniteMagnitude)
            case .cost: return (a.cost ?? "") < (b.cost ?? "")
            case .status:
                let statusOrder: [PeerInfo.PeerStatus: Int] = [.online: 0, .connecting: 1, .offline: 2]
                return (statusOrder[a.status] ?? 3) < (statusOrder[b.status] ?? 3)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                if !vm.configManager.configs.isEmpty {
                    Picker("虚拟网络", selection: selectedConfigIndex) {
                        ForEach(vm.configManager.configs.indices, id: \.self) { index in
                            Text(vm.configManager.configs[index].name).tag(index)
                        }
                    }
                    .frame(width: 180)
                }

                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Picker("排序方式", selection: $sortKey) {
                    ForEach(SortKey.allCases, id: \.self) { key in
                        Text(key.label).tag(key)
                    }
                }
                .frame(width: 130)

                Spacer()

                Text(vm.activeConfig?.name ?? "未选择网络")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(vm.peers.filter { $0.status == .online }.count) 在线 / \(vm.peers.count) 总计")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Peer List
            if filteredPeers.isEmpty && vm.activeConfig == nil {
                ContentUnavailableView(
                    "未选择虚拟网络",
                    systemImage: "rectangle.stack.badge.person.crop",
                    description: Text("请先在当前页面选择一个虚拟网络")
                )
            } else if filteredPeers.isEmpty && !(vm.activeRuntime?.service.isRunning ?? false) {
                ContentUnavailableView(
                    "未连接",
                    systemImage: "network.slash",
                    description: Text("启动 EasyTier 以查看已连接的节点")
                )
            } else if filteredPeers.isEmpty {
                ContentUnavailableView(
                    "未找到节点",
                    systemImage: "magnifyingglass",
                    description: Text("请尝试调整搜索条件")
                )
            } else {
                Table(filteredPeers) {
                    TableColumn("状态") { peer in
                        Image(systemName: peer.status == .online ? "checkmark.circle.fill" :
                                peer.status == .connecting ? "arrow.clockwise.circle.fill" :
                                "xmark.circle.fill")
                            .foregroundColor(peer.status == .online ? .green :
                                                peer.status == .connecting ? .orange : .gray)
                    }
                    .width(60)

                    TableColumn("主机名") { peer in
                        Text(peer.hostname)
                            .font(.system(.body, design: .monospaced))
                    }

                    TableColumn("IPv4") { peer in
                        Text(peer.ipv4)
                            .font(.system(.body, design: .monospaced))
                            .contextMenu {
                                Button("复制 IPv4") {
                                    copyToPasteboard(peer.ipv4)
                                }
                            }
                    }

                    TableColumn("节点 ID") { peer in
                        Text(peer.nodeID.prefix(12))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    TableColumn("延迟") { peer in
                        if let latency = peer.latencyMs {
                            Text("\(formatLatency(latency)) ms")
                                .foregroundColor(latencyColor(latency))
                        } else {
                            Text("-")
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(80)

                    TableColumn("连接方式") { peer in
                        Text(peer.cost ?? "-")
                            .foregroundColor(peer.cost == nil ? .secondary : .primary)
                    }
                    .width(90)
                }
                .tableStyle(.bordered)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .orange }
        return .red
    }

    private func formatLatency(_ ms: Double) -> String {
        String(format: "%.2f", ms)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    PeersView()
        .environmentObject(ProcessViewModel())
        .frame(width: 700, height: 400)
}
