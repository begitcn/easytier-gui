//
//  TopologyCanvas.swift
//  EasyTierGUI
//
//  网络拓扑可视化 Canvas
//

import SwiftUI

/// 本机节点信息
struct LocalNodeInfo {
    let hostname: String
    let ipv4: String
}

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
