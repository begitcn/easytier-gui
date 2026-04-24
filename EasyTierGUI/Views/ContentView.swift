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
                .padding(.vertical, 8)
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
