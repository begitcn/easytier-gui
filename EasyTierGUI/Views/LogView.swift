import SwiftUI
import AppKit

// MARK: - LogView

struct LogView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @AppStorage("enableLogMonitoring") private var enableLogMonitoring = false

    private var selectedConfigIndex: Binding<Int> {
        Binding(
            get: { max(vm.activeConfigIndex, 0) },
            set: { vm.configManager.setActiveConfig(at: $0) }
        )
    }

    var body: some View {
        Group {
            if !enableLogMonitoring {
                ContentUnavailableView(
                    "日志监控已关闭",
                    systemImage: "ladybug.slash",
                    description: Text("在“设置 > 通用”里开启“启用日志监控（调试）”后可查看实时日志")
                )
            } else if vm.configManager.configs.isEmpty {
                ContentUnavailableView(
                    "暂无可用网络",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("请先在连接页面创建一个虚拟网络")
                )
            } else if let runtime = vm.activeRuntime {
                LogRuntimeView(
                    service: runtime.service,
                    activeName: vm.activeConfig?.name,
                    configs: vm.configManager.configs,
                    selectedConfigIndex: selectedConfigIndex
                )
                .id(runtime.id)
            } else {
                ContentUnavailableView(
                    "未选择网络",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("请先选择一个虚拟网络")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct LogRuntimeView: View {
    @ObservedObject var service: EasyTierService
    let activeName: String?
    let configs: [EasyTierConfig]
    @Binding var selectedConfigIndex: Int

    @State private var searchText = ""
    @State private var effectiveSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var autoScroll = true
    @State private var filteredLogs: [LogEntry] = []

    private var logCount: Int { service.logEntries.count }
    private var lastLogID: UUID? { service.logEntries.last?.id }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: CGFloat.spacingM) {
                    if !configs.isEmpty {
                        Picker("", selection: $selectedConfigIndex) {
                            ForEach(configs.indices, id: \.self) { index in
                                Text(configs[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("过滤日志消息...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, CGFloat.spacingS)
                    .padding(.vertical, CGFloat.spacingXS)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .frame(maxWidth: 300)

                    Spacer()

                    Toggle("自动滚动", isOn: $autoScroll)
                        .toggleStyle(.switch)
                        .padding(.trailing, 8)

                    Button(action: { exportLogs() }) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 32, height: 32)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        service.clearLogs()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(CGFloat.cardPadding)

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
                            LazyVStack(alignment: .leading, spacing: CGFloat.spacingXS) {
                                ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                                    LogEntryRow(entry: log, showIndex: index)
                                        .id(log.id)
                                }
                            }
                            .padding(.horizontal, CGFloat.cardPadding)
                            .padding(.bottom, CGFloat.cardPadding)
                        }
                        .onChange(of: filteredLogs.last?.id) { _, newId in
                            if autoScroll, let id = newId {
                                withAnimation(.easeOut.speed(0.5)) {
                                    proxy.scrollTo(id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("\(filteredLogs.count) 条记录")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)

                    Spacer()

                    if let activeName {
                        Text(activeName)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(.primary)
                    } else {
                        Text("未选择网络")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if service.isRunning {
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
                .padding(.horizontal, CGFloat.cardPadding)
                .padding(.vertical, CGFloat.spacingS)
                .background(Color.black.opacity(0.1))
            }
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            .padding(.horizontal, CGFloat.spacingXL)
            .padding(.bottom, CGFloat.spacingXL)
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                effectiveSearchText = newValue
            }
        }
        .onChange(of: effectiveSearchText) { _, _ in
            updateFilteredLogs()
        }
        .onChange(of: logCount) { _, _ in
            updateFilteredLogs()
        }
        .onChange(of: lastLogID) { _, _ in
            updateFilteredLogs()
        }
        .onAppear {
            effectiveSearchText = searchText
            updateFilteredLogs()
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
    }

    private func updateFilteredLogs() {
        let logs = service.logEntries
        guard !effectiveSearchText.isEmpty else {
            filteredLogs = logs
            return
        }

        let query = effectiveSearchText.lowercased()
        filteredLogs = logs.filter { $0.message.lowercased().contains(query) }
    }

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

#Preview {
    LogView()
        .environmentObject(ProcessViewModel())
        .frame(width: 700, height: 400)
}
