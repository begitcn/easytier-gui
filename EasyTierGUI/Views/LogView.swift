import SwiftUI

// MARK: - LogView
// Real-time log viewer with filtering capabilities

struct LogView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var searchText = ""
    @State private var selectedLevel: String = "全部"
    @State private var autoScroll = true
    @State private var showLogLevels = true

    var logLevels: [String] = ["全部", "调试", "信息", "警告", "错误"]

    var filteredLogs: [LogEntry] {
        var logs = vm.activeRuntime?.service.logEntries ?? []

        // Filter by level
        if selectedLevel != "全部" {
            let levelMap = ["调试": "debug", "信息": "info", "警告": "warn", "错误": "error"]
            if let levelFilter = levelMap[selectedLevel] {
                logs = logs.filter { $0.level.lowercased() == levelFilter }
            }
        }

        // Filter by search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            logs = logs.filter { $0.message.lowercased().contains(query) }
        }

        return logs
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("运行日志")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 16) {
                    // Level filter
                    Picker("", selection: $selectedLevel) {
                        ForEach(logLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("过滤日志消息...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .frame(maxWidth: 300)

                    Spacer()

                    // Controls
                    Toggle("自动滚动", isOn: $autoScroll)
                        .toggleStyle(.switch)
                        .padding(.trailing, 8)

                    Button(action: {
                        exportLogs()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 32, height: 32)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        vm.clearActiveLogs()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)

                // Log Content
                if filteredLogs.isEmpty {
                    ContentUnavailableView(
                        "暂无日志",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("当前过滤条件下没有记录或网络未运行")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                                    LogEntryRow(entry: log, showIndex: index)
                                        .id(log.id)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: filteredLogs.count) { _, _ in
                            if autoScroll, let lastLog = filteredLogs.last {
                                withAnimation(.easeOut.speed(0.5)) {
                                    proxy.scrollTo(lastLog.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                // Status bar
                HStack {
                    Text("\(filteredLogs.count) 条记录")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)

                    Spacer()

                    if let activeName = vm.activeConfig?.name {
                        Text(activeName)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text("未选择网络")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if vm.activeRuntime?.service.isRunning ?? false {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .shadow(color: .green.opacity(0.5), radius: 2)
                            Text("实时监控")
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("已停止")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.1))
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
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Export

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "easytier_logs_\(formattedDate()).txt"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let logText = filteredLogs.map { entry in
                "[\(entry.timestamp.formatted())] [\(entry.level.uppercased())] \(entry.message)"
            }.joined(separator: "\n")

            try? logText.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let entry: LogEntry
    let showIndex: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
                .padding(.top, 4)

            Text(entry.level.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(entry.levelColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(entry.levelColor.opacity(0.15))
                .clipShape(Capsule())
                .frame(width: 60, alignment: .leading)
                .padding(.top, 2)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary.opacity(0.9))
                .textSelection(.enabled)
                .lineLimit(nil)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(logBackgroundColor)
        .cornerRadius(8)
    }

    private var logBackgroundColor: Color {
        switch entry.level.lowercased() {
        case "error", "err":
            return Color.red.opacity(0.08)
        case "warn", "warning":
            return Color.orange.opacity(0.08)
        default:
            return showIndex % 2 == 0 ? Color(NSColor.controlBackgroundColor).opacity(0.2) : Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    LogView()
        .environmentObject(ProcessViewModel())
        .frame(width: 700, height: 400)
}
