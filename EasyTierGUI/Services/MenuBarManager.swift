import AppKit
import SwiftUI

// MARK: - MenuBarManager
// Manages the system menu bar status item

class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    var statusItem: NSStatusItem?
    var isRunning = false

    @Published var connectionStatus: NetworkStatus = .disconnected
    private var networkStatuses: [(name: String, status: NetworkStatus)] = []

    func setupMenuBar() {
        if !UserDefaults.standard.bool(forKey: "showMenuBar") && UserDefaults.standard.object(forKey: "showMenuBar") != nil {
            return
        }

        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }

        if let button = statusItem?.button {
            updateIcon(status: connectionStatus)
            button.target = self
            button.action = #selector(handleTrayClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // We don't attach the menu directly to statusItem anymore so we can control the click
        // statusItem?.menu = buildMenu() 
    }

    @objc private func handleTrayClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            let menu = buildMenu()
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil // Reset so it doesn't always show on left click
        } else {
            AppDelegate.shared?.showMainWindowWithDock()
        }
    }

    func setVisible(_ visible: Bool) {
        if visible {
            setupMenuBar()
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    func updateIcon(status: NetworkStatus) {
        guard let button = statusItem?.button else { return }
        connectionStatus = status

        let symbolName: String
        switch status {
        case .disconnected: symbolName = "network.slash"
        case .connecting:   symbolName = "network.connect"
        case .connected:    symbolName = "network"
        case .error:        symbolName = "exclamationmark.triangle"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "EasyTier Status") {
            switch status {
            case .connected:
                // Render in green — not template so the tint color shows
                image.isTemplate = false
                guard let tinted = image.copy() as? NSImage else { return }
                tinted.lockFocus()
                NSColor.systemGreen.withAlphaComponent(0.9).set()
                NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
                tinted.unlockFocus()
                button.image = tinted
            case .connecting:
                image.isTemplate = false
                guard let tinted = image.copy() as? NSImage else { return }
                tinted.lockFocus()
                NSColor.systemOrange.withAlphaComponent(0.9).set()
                NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
                tinted.unlockFocus()
                button.image = tinted
            default:
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "EasyTier - \(status.description)"
        }
    }

    func updateStatus(_ status: NetworkStatus, networkStatuses: [(name: String, status: NetworkStatus)] = []) {
        self.networkStatuses = networkStatuses
        updateIcon(status: status)
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Overall status
        let statusText = connectionStatus.description
        let statusItem = NSMenuItem(title: "总状态: \(statusText)", action: nil, keyEquivalent: "")
        menu.addItem(statusItem)
        
        if !networkStatuses.isEmpty {
            menu.addItem(NSMenuItem.separator())
            let header = NSMenuItem(title: "虚拟组网状态:", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            
            for (name, status) in networkStatuses {
                let dot = status == .connected ? "●" : (status == .connecting ? "○" : "○")
                let item = NSMenuItem(title: "  \(dot) \(name): \(status.description)", action: nil, keyEquivalent: "")
                // We could add actions here to connect/disconnect if needed
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "打开 EasyTier", action: #selector(AppDelegate.openMainWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }
}

extension AppDelegate {
    @objc func openMainWindow(_ sender: Any) {
        AppDelegate.shared?.showMainWindowWithDock()
    }
}
