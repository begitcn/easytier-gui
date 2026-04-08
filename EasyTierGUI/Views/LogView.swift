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
            // Toolbar
            HStack(spacing: 12) {
                // Level filter
                Picker("级别", selection: $selectedLevel) {
                    ForEach(logLevels, id: \.self) { level in
                        Text(level).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                // Search
                TextField("搜索日志...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 250)

                Spacer()

                // Auto-scroll toggle
                Toggle("自动滚动", isOn: $autoScroll)
                    .labelsHidden()
                    .toggleStyle(.switch)

                // Clear button
                Button("清空", systemImage: "trash") {
                    vm.clearActiveLogs()
                }
                .buttonStyle(.bordered)

                // Export button
                Button("导出", systemImage: "square.and.arrow.up") {
                    exportLogs()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Log Content
            if filteredLogs.isEmpty {
                ContentUnavailableView(
                    "暂无日志",
                    systemImage: "doc.text",
                    description: Text("EasyTier 运行时日志将显示在这里")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                                LogEntryRow(entry: log, showIndex: index)
                                    .id(log.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
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

            Divider()

            // Status bar
            HStack {
                Text("\(filteredLogs.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(vm.activeConfig?.name ?? "未选择网络")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if vm.activeRuntime?.service.isRunning ?? false {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                    Text("实时")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)

            Text(entry.level.uppercased())
                .font(.caption.monospaced())
                .fontWeight(.medium)
                .foregroundColor(entry.levelColor)
                .frame(width: 50, alignment: .leading)

            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(logBackgroundColor)
        .cornerRadius(3)
    }

    private var logBackgroundColor: Color {
        switch entry.level.lowercased() {
        case "error", "err":
            return Color.red.opacity(0.08)
        case "warn", "warning":
            return Color.orange.opacity(0.08)
        default:
            return Color.clear
        }
    }
}

// MARK: - Preview

#Preview {
    LogView()
        .environmentObject(ProcessViewModel())
        .frame(width: 700, height: 400)
}
