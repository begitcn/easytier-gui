import SwiftUI

// MARK: - ContentView
// Main application window with sidebar navigation

struct ContentView: View {
    @EnvironmentObject var vm: ProcessViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            DetailView()
        }
        .navigationTitle("EasyTier")
        .toolbar {
            ToolbarItem(placement: .status) {
                statusIndicator
            }
        }
    }

    // MARK: - Status Indicator

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vm.status.color)
                .frame(width: 8, height: 8)
                .shadow(color: vm.status.color.opacity(0.6), radius: 3)
            Text(vm.status.description)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(vm.status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(vm.status.color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(vm.status.color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var vm: ProcessViewModel

    var body: some View {
        List(AppTab.allCases, selection: $vm.selectedTab) { tab in
            Label(tab.label, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Detail View Router

struct DetailView: View {
    @EnvironmentObject var vm: ProcessViewModel

    var body: some View {
        switch vm.selectedTab {
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
