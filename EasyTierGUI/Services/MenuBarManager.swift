import AppKit
import SwiftUI

// MARK: - MenuBarManager
// Manages the system menu bar status item

class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    var statusItem: NSStatusItem?
    var isRunning = false

    @Published var connectionStatus: NetworkStatus = .disconnected

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if statusItem?.button != nil {
            updateIcon(status: connectionStatus)
        }

        statusItem?.menu = buildMenu()
    }

    func updateIcon(status: NetworkStatus) {
        guard let button = statusItem?.button else { return }
        connectionStatus = status

        // Use system symbol based on status
        let symbolName: String
        switch status {
        case .disconnected: symbolName = "network.slash"
        case .connecting: symbolName = "network.connect"
        case .connected: symbolName = "network"
        case .error: symbolName = "exclamationmark.triangle"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "EasyTier Status") {
            image.isTemplate = true
            button.image = image
            button.toolTip = "EasyTier - \(status.description)"
        }
    }

    func updateStatus(_ status: NetworkStatus) {
        updateIcon(status: status)
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let statusText = connectionStatus.description
        menu.addItem(NSMenuItem(title: statusText, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "打开 EasyTier", action: #selector(AppDelegate.openMainWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}

extension AppDelegate {
    @objc func openMainWindow(_ sender: Any) {
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}
