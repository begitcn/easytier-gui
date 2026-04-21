//
//  UpdateBanner.swift
//  EasyTierGUI
//
//  更新提示横幅组件
//

import SwiftUI

// MARK: - Update Banner

/// 更新提示横幅
struct UpdateBanner: View {
    let version: BinaryVersion
    let onUpdate: () -> Void
    let onSkip: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主横幅
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("发现新版本 \(version.displayVersion)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("点击展开查看更新内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onUpdate) {
                    Text("更新")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
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
                    Text("更新内容")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(version.releaseNotesSummary)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Download Progress Banner

/// 下载进度横幅
struct DownloadProgressBanner: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("正在更新...")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 进度条
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
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Update Complete Banner

/// 更新完成横幅
struct UpdateCompleteBanner: View {
    let version: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("更新完成")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text("已安装版本 v\(version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("确定")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Error Banner

/// 错误横幅
struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("更新失败")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRetry) {
                Text("重试")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Update Available") {
    UpdateBanner(
        version: BinaryVersion(
            version: "1.2.5",
            tagName: "v1.2.5",
            releaseNotes: "## 新功能\n- 支持自动更新\n- 修复连接稳定性问题\n\n## 改进\n- 性能优化",
            downloadURL: URL(string: "https://example.com")!,
            publishedAt: Date()
        ),
        onUpdate: {},
        onSkip: {}
    )
    .padding()
    .frame(width: 400)
}

#Preview("Download Progress") {
    DownloadProgressBanner(progress: 0.65)
        .padding()
        .frame(width: 400)
}

#Preview("Update Complete") {
    UpdateCompleteBanner(version: "1.2.5", onDismiss: {})
        .padding()
        .frame(width: 400)
}

#Preview("Error") {
    ErrorBanner(message: "网络连接失败", onRetry: {}, onDismiss: {})
        .padding()
        .frame(width: 400)
}
