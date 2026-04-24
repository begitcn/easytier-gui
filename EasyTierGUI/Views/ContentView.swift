import SwiftUI

// MARK: - ContentView
// Main application window with sidebar navigation

struct ContentView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedTab: AppTab = .connection

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            DetailView(selectedTab: selectedTab)
        }
        .navigationTitle("EasyTier")
        .toast(message: $vm.toastMessage)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    switch event.charactersIgnoringModifiers {
                    case "1":
                        selectedTab = .connection
                        return nil
                    case "2":
                        selectedTab = .peers
                        return nil
                    case "3":
                        selectedTab = .logs
                        return nil
                    case "4":
                        selectedTab = .settings
                        return nil
                    case "r", "R":
                        Task { @MainActor in
                            await vm.refreshPeers()
                        }
                        return nil
                    default:
                        break
                    }
                }
                return event
            }
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var vm: ProcessViewModel

    var body: some View {
        VStack(spacing: 0) {
            if vm.isInitializing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("初始化中...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, CGFloat.spacingXS)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }

            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
        }
    }
}

// MARK: - Detail View Router

struct DetailView: View {
    let selectedTab: AppTab

    var body: some View {
        switch selectedTab {
        case .connection:
            ConnectionView()
        case .peers:
            PeersView()
        case .logs:
            LogView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(ProcessViewModel())
        .frame(width: 800, height: 500)
}

// MARK: - Spacing Constants (macOS HIG 8pt Grid)

extension CGFloat {
    /// Component internal spacing: 8pt
    static let spacingXS: CGFloat = 8
    /// Component internal spacing: 12pt
    static let spacingS: CGFloat = 12
    /// Component internal spacing: 16pt
    static let spacingM: CGFloat = 16
    /// Container spacing: 20pt
    static let spacingL: CGFloat = 20
    /// Container spacing: 24pt
    static let spacingXL: CGFloat = 24
    /// Card internal padding: 20pt
    static let cardPadding: CGFloat = 20
    /// Card spacing: 24pt
    static let cardSpacing: CGFloat = 24
}
