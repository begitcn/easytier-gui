# Phase 5: Network Statistics - Implementation Patterns

**Generated:** 2026-04-25
**Phase:** 05-network-statistics

---

## Overview

This document maps each file identified in 05-RESEARCH.md to its closest existing analog in the codebase. Each mapping includes concrete code excerpts demonstrating the pattern to follow.

---

## File Classification by Role

| File | Role | Data Flow |
|------|------|-----------|
| `Models/Models.swift` (extension) | Data Model | Add `lastUpdated` timestamp to `PeerInfo` |
| `Views/TopologyCanvas.swift` | NEW: Visual Component | Canvas drawing for network topology |
| `Views/CollapsibleTopologyView.swift` | NEW: Container Component | Expand/collapse wrapper with state |
| `Views/PeersView.swift` | Modification: Integration | Add topology section, stale indicators |
| `Services/ProcessViewModel.swift` | Modification: State | Preserve peers on disconnect |

---

## 1. Model Extension: PeerInfo.lastUpdated

### Closest Analog: `ToastMessage` struct in Models.swift

The project already extends simple structs with additional fields. The `PeerInfo` structure can be extended similarly.

**Existing Pattern (Models.swift lines 148-164):**
```swift
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
```

**Recommended Extension (add to PeerInfo):**
```swift
    // MARK: - Phase 5: Network Statistics
    var lastUpdated: Date?    // 最后更新时间（用于过期检测）
    
    /// 判定节点是否已过期（超过 10 秒未更新）
    var isStale: Bool {
        guard let lastUpdated = lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) > 10
    }
```

---

## 2. NEW: TopologyCanvas.swift

### Closest Analog: None (no existing Canvas usage)

However, the project uses SwiftUI drawing in other ways:
- `GeometryReader` for progress bar in `UpdateBanner.swift` (lines 116-127)
- `Circle().path(in:)` pattern can be adapted

**Reference Pattern from UpdateBanner.swift (lines 116-127):**
```swift
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.gray.opacity(0.3))

        RoundedRectangle(cornerRadius: 3)
            .fill(Color.blue)
            .frame(width: geometry.size.width * progress)
    }
}
.frame(height: 6)
```

**Recommended TopologyCanvas Implementation:**
```swift
import SwiftUI

/// 网络拓扑可视化 Canvas
struct TopologyCanvas: View {
    let peers: [PeerInfo]
    let localNode: LocalNodeInfo
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let localNodeRadius: CGFloat = 30
            
            // Draw local node at center
            let localNodeRect = CGRect(
                x: center.x - localNodeRadius,
                y: center.y - localNodeRadius,
                width: localNodeRadius * 2,
                height: localNodeRadius * 2
            )
            context.fill(
                Circle().path(in: localNodeRect),
                with: .color(.accentColor)
            )
            
            // Draw local node label
            let localLabel = Text("本机")
                .font(.caption2)
            context.draw(localLabel, at: CGPoint(x: center.x, y: center.y + 45))
            
            // Draw peer nodes in radial pattern
            guard !peers.isEmpty else { return }
            let peerRadius = min(size.width, size.height) / 2 - 60
            for (index, peer) in peers.enumerated() {
                let angle = (2 * .pi / CGFloat(peers.count)) * CGFloat(index) - .pi / 2
                let peerPosition = CGPoint(
                    x: center.x + peerRadius * cos(angle),
                    y: center.y + peerRadius * sin(angle)
                )
                
                // Draw connection line from center to peer
                let linePath = Path { path in
                    path.move(to: center)
                    path.addLine(to: peerPosition)
                }
                
                // Color line based on latency
                let lineColor = latencyColor(peer.latencyMs)
                context.stroke(linePath, with: .color(lineColor), lineWidth: 2)
                
                // Draw peer node
                let peerRect = CGRect(
                    x: peerPosition.x - 15,
                    y: peerPosition.y - 15,
                    width: 30,
                    height: 30
                )
                let peerColor: Color = peer.isStale ? .gray : .secondary
                context.fill(
                    Circle().path(in: peerRect),
                    with: .color(peerColor)
                )
                
                // Draw latency label near peer
                if let latency = peer.latencyMs {
                    let labelText = Text("\(String(format: "%.0f", latency))ms")
                        .font(.caption2)
                    context.draw(labelText, at: CGPoint(x: peerPosition.x, y: peerPosition.y + 25))
                }
            }
        }
    }
    
    private func latencyColor(_ ms: Double?) -> Color {
        guard let ms = ms else { return .gray }
        if ms < 50 { return .green }
        if ms < 150 { return .orange }
        return .red
    }
}

/// 本机节点信息
struct LocalNodeInfo {
    let hostname: String
    let ipv4: String
}
```

---

## 3. NEW: CollapsibleTopologyView.swift

### Closest Analog: `UpdateBanner.swift` (lines 12-89)

The project already has a working expand/collapse pattern with animation.

**Existing Pattern (UpdateBanner.swift lines 17-64):**
```swift
struct UpdateBanner: View {
    let version: BinaryVersion
    let onUpdate: () -> Void
    let onSkip: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主横幅
            HStack(spacing: 12) {
                // ... header content
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // 展开的详情
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    // ... expanded content
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
```

**Recommended CollapsibleTopologyView Implementation:**
```swift
import SwiftUI

/// 可折叠的网络拓扑视图
struct CollapsibleTopologyView: View {
    @Binding var isExpanded: Bool
    let peers: [PeerInfo]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    
                    Text("网络拓扑")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    
                    Text("\(peers.count) 个节点")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, CGFloat.cardPadding)
                .padding(.vertical, CGFloat.spacingS)
            }
            .buttonStyle(.plain)
            
            // Topology canvas (when expanded)
            if isExpanded {
                TopologyCanvas(
                    peers: peers,
                    localNode: LocalNodeInfo(
                        hostname: Host.current().localizedName ?? "本机",
                        ipv4: "127.0.0.1"
                    )
                )
                .frame(height: 250)
                .padding(CGFloat.cardPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
```

---

## 4. Modification: PeersView.swift

### Closest Analog: Self (existing PeersView)

This file will be modified to add:
1. Collapsible topology section above peer list
2. Stale indicator on peer rows

**Existing Pattern (PeersView.swift lines 59-182):**
```swift
var body: some View {
    VStack(spacing: 0) {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: CGFloat.spacingM) {
                // ... toolbar content
            }
            .padding(CGFloat.cardPadding)

            // Peer List
            if /* empty states */ {
                // ... ContentUnavailableView
            } else {
                VStack(spacing: 0) {
                    // Header row
                    // List with peer rows
                }
            }
        }
        .background(.ultraThinMaterial)
        // ... styling
    }
}
```

**Stale Indicator Pattern (from peerRow method lines 214-269):**
```swift
@ViewBuilder
private func peerRow(peer: PeerInfo) -> some View {
    let isLocal = peer.cost == "Local"

    HStack(spacing: CGFloat.spacingM) {
        // ... existing content
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .contentShape(Rectangle())
    .opacity(peer.isStale ? 0.5 : 1.0)  // NEW: Gray out stale peers
    .overlay(alignment: .topTrailing) {
        if peer.isStale {  // NEW: "已断开" label
            Text("已断开")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .offset(x: 8, y: -4)
        }
    }
    .hoverEffect()
    .listRowBackground(
        isLocal ? Color.accentColor.opacity(0.12) : Color.clear
    )
}
```

**Recommended PeersView Modification:**
```swift
struct PeersView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var searchText = ""
    @State private var sortKey: SortKey = .ipv4
    @State private var isTopologyExpanded: Bool = false  // NEW

    // ... existing code ...

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // NEW: Collapsible topology section
                if vm.activeRuntime?.service.isRunning == true || !vm.peers.isEmpty {
                    CollapsibleTopologyView(
                        isExpanded: $isTopologyExpanded,
                        peers: vm.peers
                    )
                }
                
                // Existing toolbar
                // ... (no changes needed)
                
                // Existing peer list
                // ... (no changes needed, but add stale indicator per above)
            }
            // ... existing styling
        }
    }
}
```

---

## 5. Modification: ProcessViewModel.swift

### Closest Analog: Self (existing state management)

Currently at lines 50-54, peers are cleared on disconnect:
```swift
} else {
    self.status = .disconnected
    self.stopPeerPolling()
    self.peers.removeAll()  // Line 53 - PROBLEM per D-09
}
```

**Recommended Change (preserve stale tracking):**
```swift
// In NetworkRuntime, add property:
@Published var lastKnownPeers: [PeerInfo] = []  // Preserve on disconnect

// Modify the service.$isRunning sink (around line 43-57):
service.$isRunning
    .receive(on: DispatchQueue.main)
    .sink { [weak self] isRunning in
        guard let self = self else { return }
        if isRunning {
            self.status = .connected
            self.startPeerPolling()
        } else {
            self.status = .disconnected
            self.stopPeerPolling()
            // Keep last known peers but mark as stale (D-09)
            self.lastKnownPeers = self.peers.map { peer in
                var stalePeer = peer
                stalePeer.lastUpdated = nil  // Mark as stale
                return stalePeer
            }
        }
        self.onStateChange?()
    }
    .store(in: &cancellables)

// Modify fetchPeers to set lastUpdated:
private func fetchPeers() {
    // ... existing code ...
    service.fetchPeers(rpcPortalPort: port) { [weak self] newPeers in
        DispatchQueue.main.async {
            guard let self = self else { return }
            let now = Date()
            if self.peers != newPeers {
                self.peers = newPeers.map { peer in
                    var updatedPeer = peer
                    updatedPeer.lastUpdated = now
                    return updatedPeer
                }
                self.onStateChange?()
            }
        }
    }
}

// Expose combined peers for display (active + stale):
var displayPeers: [PeerInfo] {
    if peers.isEmpty && !lastKnownPeers.isEmpty {
        return lastKnownPeers
    }
    return peers
}
```

---

## Integration Checklist

| Step | File | Action |
|------|------|--------|
| 1 | `Models/Models.swift` | Add `lastUpdated` and `isStale` to `PeerInfo` |
| 2 | `Views/TopologyCanvas.swift` | Create new file with Canvas drawing |
| 3 | `Views/CollapsibleTopologyView.swift` | Create new file with expand/collapse |
| 4 | `Views/PeersView.swift` | Add topology section, stale indicators |
| 5 | `Services/ProcessViewModel.swift` | Preserve peers on disconnect |

---

## References

- **Canvas Pattern:** `UpdateBanner.swift` (GeometryReader usage)
- **Expand/Collapse:** `UpdateBanner.swift` (`@State isExpanded`, `withAnimation`)
- **Peer List:** `Views/PeersView.swift`
- **Model Structure:** `Models/Models.swift` (`PeerInfo`)
- **State Management:** `Services/ProcessViewModel.swift` (`NetworkRuntime`)

---

*Patterns generated: 2026-04-25*
*Next: Implementation following these patterns*
