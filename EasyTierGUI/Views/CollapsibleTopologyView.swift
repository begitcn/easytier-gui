//
//  CollapsibleTopologyView.swift
//  EasyTierGUI
//
//  可折叠的网络拓扑视图
//

import SwiftUI

/// 可折叠的网络拓扑视图
struct CollapsibleTopologyView: View {
    @Binding var isExpanded: Bool
    let peers: [PeerInfo]
    let localNode: LocalNodeInfo

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
                    localNode: localNode
                )
                .frame(height: 250)
                .padding(CGFloat.cardPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
}
