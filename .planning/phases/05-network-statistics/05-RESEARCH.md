# Phase 5: Network Statistics - Research

**Research Date:** 2026-04-25
**Phase:** 05-network-statistics

---

## Executive Summary

This phase implements network statistics display: latency for each peer, topology visualization, and stale data feedback when disconnected. Key findings:

- **Latency display** already exists in `PeerInfo.latencyMs` and `PeersView` - minimal work required
- **Topology visualization** should use SwiftUI Canvas with simplified radial layout
- **Stale data indication** requires adding connection state tracking to `PeerInfo`
- **Integration** leverages existing 5-second peer polling without changes

---

## 1. Technical Approach: SwiftUI Canvas Topology

### 1.1 Canvas vs. Path/Shape Alternatives

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| **Canvas** | Full drawing control, better performance for many nodes | More complex API | ✅ Recommended |
| **Path/Shapes** | Simpler SwiftUI integration | Limited to simple lines | For simple needs |
| **第三方库** | Pre-built features |额外依赖 | Avoid |

**Decision:** Use SwiftUI `Canvas` API for topology visualization.

### 1.2 Canvas Implementation Pattern

```swift
struct TopologyCanvas: View {
    let peers: [PeerInfo]
    let localNode: LocalNodeInfo
    
    var body: some View {
        Canvas { context, size in
            // Calculate node positions (radial layout)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let localNodeRadius: CGFloat = 40
            
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
            
            // Draw peer nodes in radial pattern
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
                    x: peerPosition.x - 20,
                    y: peerPosition.y - 20,
                    width: 40,
                    height: 40
                )
                context.fill(
                    Circle().path(in: peerRect),
                    with: .color(.secondary)
                )
                
                // Draw latency label near peer
                if let latency = peer.latencyMs {
                    let labelPosition = CGPoint(
                        x: peerPosition.x,
                        y: peerPosition.y + 30
                    )
                    let text = Text("\(String(format: "%.0f", latency))ms")
                        .font(.caption2)
                    context.draw(text, at: labelPosition)
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
```

### 1.3 Layout Algorithm

Based on D-03 (simplified hierarchical view):

- **Center node:** Local machine with "本机" label
- **Perimeter nodes:** All connected peers in radial pattern
- **Connection lines:** Draw from center to each peer
- **Latency labels:** Displayed on connection lines

**Radial position calculation:**
```swift
func calculatePeerPosition(index: Int, total: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
    let angle = (2 * .pi / CGFloat(total)) * CGFloat(index) - .pi / 2
    return CGPoint(
        x: center.x + radius * cos(angle),
        y: center.y + radius * sin(angle)
    )
}
```

### 1.4 Interaction Considerations

Per D-05 (Canvas drawing), basic interactions:
- **Hover:** Highlight node and show tooltip with peer details
- **Click:** Select peer row in list (coordinate with existing selection)
- **Pan/Zoom:** Optional, defer to v2 if complex

For interaction, use `Canvas` with `GestureModifier`:
```swift
Canvas { context, size in
    // Drawing code
}
.gesture(
    TapGesture()
        .onEnded { location in
            // Detect tapped node
        }
)
```

---

## 2. Stale Data Indication

### 2.1 Current State

Currently, when network disconnects:
- `NetworkRuntime.status` becomes `.disconnected`
- `NetworkRuntime.peers` is cleared: `self.peers.removeAll()`
- `PeersView` shows "未连接网络" empty state

**Problem:** D-09 states "保留历史数据，让用户能看到最后的状态"

### 2.2 Required Changes

**Option A: Track disconnection separately**
Keep last known peers in a separate property, don't clear on disconnect.

**Option B: Add connection state to each peer**
Extend `PeerInfo` with `lastSeen` timestamp.

**Recommendation:** Option B with fallback display

### 2.3 Model Extension

```swift
// In Models.swift - extend PeerInfo
struct PeerInfo: Identifiable, Equatable {
    var id: String { "\(nodeID)|\(ipv4)" }
    var nodeID: String
    var ipv4: String
    var hostname: String
    var status: PeerStatus
    var latencyMs: Double?
    var cost: String?
    var tunnelProto: String?
    var location: String?
    
    // NEW: Track staleness
    var lastUpdated: Date?
    var isStale: Bool { 
        guard let lastUpdated = lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) > 10 // > 2x polling interval
    }
    
    enum PeerStatus: String, Equatable {
        case online, offline
    }
}
```

### 2.4 UI Feedback Implementation

**Visual indication per D-08 (灰显 + 标签):**

```swift
// In PeersView.swift - peerRow modifier
private func peerRow(peer: PeerInfo) -> some View {
    HStack(spacing: CGFloat.spacingM) {
        // ... existing row content
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .opacity(peer.isStale ? 0.5 : 1.0)  // Gray out stale
    .overlay(alignment: .topTrailing) {
        if peer.isStale {
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
}
```

### 2.5 Data Retention Strategy

**In ProcessViewModel.swift - NetworkRuntime:**

```swift
// Currently (line 51-54):
if isRunning {
    self.status = .connected
    self.startPeerPolling()
} else {
    self.status = .disconnected
    self.stopPeerPolling()
    self.peers.removeAll()  // PROBLEM: Clears history
}

// Recommended change:
} else {
    self.status = .disconnected
    self.stopPeerPolling()
    // Keep peers but mark as stale
    for index in peers.indices {
        peers[index].lastUpdated = nil
    }
}
```

**Actually, better approach:** Track last known peers separately:

```swift
@Published var peers: [PeerInfo] = []
private var lastKnownPeers: [PeerInfo] = []  // Keep history

// In disconnect():
self.status = .disconnected
self.stopPeerPolling()
// Don't clear peers - keep lastKnownPeers for display
```

---

## 3. Integration with Existing Peer Polling

### 3.1 Current Polling Architecture

**ProcessViewModel.swift lines 145-178:**
```swift
private func startPeerPolling() {
    peerTimer?.invalidate()
    peerTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.fetchPeers()
        }
    }
    fetchPeers()  // Initial fetch
}

private func fetchPeers() {
    guard let port = currentRPCPortalPort else {
        peers = []
        return
    }
    
    service.fetchPeers(rpcPortalPort: port) { [weak self] newPeers in
        DispatchQueue.main.async {
            guard let self = self else { return }
            if self.peers != newPeers {
                self.peers = newPeers
                self.onStateChange?()
            }
        }
    }
}
```

### 3.2 No Changes Required

Per D-06 (保持 5 秒轮询), the existing polling mechanism works:

1. **STAT-04 (Periodic updates):** Already 5-second interval ✅
2. **STAT-01 (Latency display):** Already fetched via `latencyMs` field ✅
3. **STAT-02 (Bytes sent/received):** Deferred to v2, but CLI may already provide this

**Minor enhancement:** Update `lastUpdated` timestamp when peers are fetched:

```swift
// In fetchPeers completion handler
self.peers = newPeers.map { peer in
    var updatedPeer = peer
    updatedPeer.lastUpdated = Date()
    return peer
}
```

### 3.3 Data Flow Summary

```
easytier-cli peer list
        ↓
   EasyTierService.fetchPeers()
        ↓
   NetworkRuntime.fetchPeers() callback
        ↓
   NetworkRuntime.peers @Published
        ↓
   PeersView (list + topology)
```

**Integration points:**
- `PeersView.swift` - Add topology section above/below list
- `Models.swift` - Optional: add `lastUpdated` field
- No changes to `EasyTierService` or polling timer needed

---

## 4. UI Structure

### 4.1 PeersView Extension

Per D-10 and D-11 (extend PeersView, collapsible topology):

```swift
struct PeersView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var searchText = ""
    @State private var sortKey: SortKey = .ipv4
    @State private var isTopologyExpanded: Bool = false  // NEW
    
    var body: some View {
        VStack(spacing: 0) {
            // NEW: Collapsible topology section
            if vm.activeRuntime?.service.isRunning == true {
                CollapsibleTopologyView(
                    isExpanded: $isTopologyExpanded,
                    peers: vm.peers
                )
            }
            
            // Existing toolbar + peer list
            // ... 
        }
    }
}

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
                    Text("网络拓扑")
                    Text("\(peers.count) 个节点")
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
                        ipv4: getLocalIP()
                    )
                )
                .frame(height: 250)
                .padding(CGFloat.cardPadding)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
```

### 4.2 Topology View Placement

Based on D-10 (extend existing PeersView):

- **Location:** Above the toolbar, below the search bar
- **Default state:** Collapsed (per D-11: "allow user to expand/collapse")
- **Expand button:** Visible always, shows node count when collapsed

---

## 5. Validation Architecture (Nyquist Framework)

### 5.1 Validation Strategy

Per project conventions, implement validation using the existing pattern from Phase 4 (toast feedback):

```swift
// MARK: - Validation Helpers

private func validateStatisticsFeature() -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    
    // V-01: Latency display verification
    let latencyPeers = vm.peers.filter { $0.latencyMs != nil }
    if vm.activeRuntime?.service.isRunning == true && latencyPeers.isEmpty {
        issues.append(ValidationIssue(
            severity: .warning,
            message: "已连接但无法获取延迟数据，请检查 easytier-cli 版本"
        ))
    }
    
    // V-02: Topology rendering verification
    if vm.peers.count > 20 {
        issues.append(ValidationIssue(
            severity: .info,
            message: "节点数量 (\(vm.peers.count)) 较多，拓扑视图可能需要滚动"
        ))
    }
    
    return issues
}
```

### 5.2 Test Scenarios

| ID | Requirement | Test | Expected Result |
|----|-------------|------|-----------------|
| T-STAT-01 | STAT-01 | Connect to network with 3 peers | Each peer shows latency in list and topology |
| T-STAT-02 | STAT-02 | (Deferred to v2) | N/A |
| T-STAT-03 | STAT-03 | Expand topology view | Radial visualization shows with local node at center |
| T-STAT-04 | STAT-04 | Wait 10 seconds | Latency updates every 5 seconds |
| T-STAT-05 | STAT-05 | Disconnect network | Peers remain visible but grayed with "已断开" label |

### 5.3 Edge Cases

1. **No peers connected:** Show empty topology (just local node)
2. **Many peers (>20):** Consider scroll/pagination
3. **Peer data changes rapidly:** Throttle UI updates (existing pattern)
4. **Network disconnects mid-update:** Keep last known state, mark stale

---

## 6. Summary: Implementation Checklist

Based on research, implementation order:

### Phase 5 Tasks

- [ ] **T1:** Add `lastUpdated` field to `PeerInfo` model (optional, for stale tracking)
- [ ] **T2:** Create `TopologyCanvas` view component
- [ ] **T3:** Create `CollapsibleTopologyView` wrapper
- [ ] **T4:** Integrate topology view into `PeersView`
- [ ] **T5:** Add stale data indication (gray + "已断开" label)
- [ ] **T6:** Preserve peer data on disconnect (keep last known peers)
- [ ] **T7:** Test latency display with real network
- [ ] **T8:** Verify topology renders correctly with 1, 5, 10+ peers

### Files to Modify

| File | Changes |
|------|---------|
| `EasyTierGUI/Models/Models.swift` | Add `lastUpdated` field (optional) |
| `EasyTierGUI/Views/PeersView.swift` | Add topology section, stale indicators |
| `EasyTierGUI/Services/ProcessViewModel.swift` | Preserve peers on disconnect |

### New Files

| File | Purpose |
|------|---------|
| `EasyTierGUI/Views/TopologyCanvas.swift` | Canvas-based topology visualization |
| `EasyTierGUI/Views/CollapsibleTopologyView.swift` | Expandable topology section |

---

## References

- **Architecture:** `.planning/codebase/ARCHITECTURE.md`
- **Conventions:** `.planning/codebase/CONVENTIONS.md`
- **Phase Context:** `.planning/phases/05-network-statistics/05-CONTEXT.md`
- **Requirements:** `.planning/REQUIREMENTS.md` (STAT-01 ~ STAT-05)
- **Prior Phase:** `.planning/milestones/v1.0-phases/01-响应性与交互反馈/01-CONTEXT.md` (Toast pattern)

---

*Research completed: 2026-04-25*
*Next: Phase planning using this research*
