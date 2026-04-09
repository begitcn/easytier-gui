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
            Text("节点详情")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    if !vm.configManager.configs.isEmpty {
                        Picker("", selection: selectedConfigIndex) {
                            ForEach(vm.configManager.configs.indices, id: \.self) { index in
                                Text(vm.configManager.configs[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("搜索节点内容...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .frame(maxWidth: 250)

                    Picker("", selection: $sortKey) {
                        ForEach(SortKey.allCases, id: \.self) { key in
                            Text("排列: \(key.label)").tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(vm.activeConfig?.name ?? "未选择网络")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(vm.peers.filter { $0.status == .online }.count) 在线 / \(vm.peers.count) 总计")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(20)

                // Peer List
                if  filteredPeers.isEmpty && vm.activeConfig == nil {
                    ContentUnavailableView(
                        "未选择虚拟网络",
                        systemImage: "rectangle.stack.badge.person.crop",
                        description: Text("请先在当前页面左上方选择一个虚拟网络")
                    )
                    .frame(maxHeight: .infinity)
                } else if filteredPeers.isEmpty && !(vm.activeRuntime?.service.isRunning ?? false) {
                    ContentUnavailableView(
                        "未连接网络",
                        systemImage: "network.slash",
                        description: Text("启动 EasyTier 以查看已连接的节点")
                    )
                    .frame(maxHeight: .infinity)
                } else if filteredPeers.isEmpty {
                    ContentUnavailableView(
                        "未找到节点",
                        systemImage: "magnifyingglass",
                        description: Text("请尝试调整搜索条件")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    Table(filteredPeers) {
                        TableColumn("状态") { peer in
                            ZStack {
                                if peer.status == .online {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                } else if peer.status == .connecting {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 24, height: 24)
                                }
                                
                                Image(systemName: peer.status == .online ? "checkmark.circle.fill" :
                                        peer.status == .connecting ? "arrow.triangle.2.circlepath.circle.fill" :
                                        "xmark.circle.fill")
                                    .foregroundColor(peer.status == .online ? .green :
                                                        peer.status == .connecting ? .orange : .gray.opacity(0.4))
                            }
                        }
                        .width(60)

                        TableColumn("主机名") { peer in
                            Text(peer.hostname)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                        }

                        TableColumn("IPv4") { peer in
                            Text(peer.ipv4)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                                .contextMenu {
                                    Button("复制 IPv4") {
                                        copyToPasteboard(peer.ipv4)
                                    }
                                }
                        }

                        TableColumn("延迟") { peer in
                            if let latency = peer.latencyMs {
                                Text("\(formatLatency(latency)) ms")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(latencyColor(latency))
                            } else {
                                Text("-")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .width(80)

                        TableColumn("连接方式") { peer in
                            Text(peer.cost ?? "-")
                                .font(.system(.caption, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(peer.cost == nil ? Color.clear : Color.accentColor.opacity(0.15))
                                .foregroundColor(peer.cost == nil ? .secondary : .accentColor)
                                .clipShape(Capsule())
                        }
                        .width(90)
                    }
                    .tableStyle(.bordered)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 15, y: 5)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
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
