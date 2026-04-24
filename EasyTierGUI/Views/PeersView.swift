import SwiftUI
import AppKit

// MARK: - PeersView
// Displays connected peers/nodes in the network

struct PeersView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var searchText = ""
    @State private var sortKey: SortKey = .ipv4

    private var selectedConfigIndex: Binding<Int> {
        Binding(
            get: { max(vm.activeConfigIndex, 0) },
            set: { vm.configManager.setActiveConfig(at: $0) }
        )
    }

    enum SortKey: String, CaseIterable {
        case hostname, ipv4, latency, cost

        var label: String {
            switch self {
            case .hostname: return "主机名"
            case .ipv4: return "IP 地址"
            case .latency: return "延迟"
            case .cost: return "连接方式"
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
            case .ipv4: return a.ipv4.localizedStandardCompare(b.ipv4) == .orderedAscending
            case .latency: return (a.latencyMs ?? Double.greatestFiniteMagnitude) < (b.latencyMs ?? Double.greatestFiniteMagnitude)
            case .cost: return (a.cost ?? "") < (b.cost ?? "")
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: CGFloat.spacingM) {
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
                    .padding(.horizontal, CGFloat.spacingS)
                    .padding(.vertical, CGFloat.spacingXS)
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

                        Text("\(vm.peers.count) 个节点")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(CGFloat.cardPadding)

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
                    VStack(spacing: 0) {
                        // 表头
                        HStack(spacing: CGFloat.spacingM) {
                            Text("主机名")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("IPv4")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("延迟")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 90, alignment: .trailing)

                            Text("连接方式")
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                        Divider()

                        // 节点列表
                        List {
                            ForEach(filteredPeers) { peer in
                                peerRow(peer: peer)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
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
    }

    private func latencyColor(_ ms: Double) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .orange }
        return .red
    }

    private func formatLatency(_ ms: Double) -> String {
        String(format: "%.2f", ms)
    }

    @ViewBuilder
    private func costBadge(cost: String?) -> some View {
        let isLocal = cost == "Local"
        let hasCost = cost != nil

        Text(cost ?? "-")
            .font(.system(.caption, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(hasCost ? (isLocal ? Color.accentColor.opacity(0.3) : Color.accentColor.opacity(0.15)) : Color.clear)
            .foregroundColor(hasCost ? .accentColor : .secondary)
            .clipShape(Capsule())
            .frame(width: 80, alignment: .center)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    @ViewBuilder
    private func peerRow(peer: PeerInfo) -> some View {
        let isLocal = peer.cost == "Local"

        HStack(spacing: CGFloat.spacingM) {
            // 主机名
            HStack(spacing: 4) {
                if isLocal {
                    Image(systemName: "star.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(.caption2))
                }
                Text(peer.hostname)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // IPv4
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
            .frame(maxWidth: .infinity, alignment: .leading)

            // 延迟
            if let latency = peer.latencyMs {
                Text("\(formatLatency(latency)) ms")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(latencyColor(latency))
                    .frame(width: 90, alignment: .trailing)
            } else {
                Text("-")
                    .foregroundColor(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }

            // 连接方式
            costBadge(cost: peer.cost)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .hoverEffect()
        .listRowBackground(
            isLocal ? Color.accentColor.opacity(0.12) : Color.clear
        )
    }
}

// MARK: - Preview

#Preview {
    PeersView()
        .environmentObject(ProcessViewModel())
        .frame(width: 700, height: 400)
}
