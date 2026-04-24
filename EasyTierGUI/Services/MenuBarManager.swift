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
    private var lastStatusSnapshot: String?

    // Cache tinted images to avoid recreating them
    private var cachedImages: [NetworkStatus: NSImage] = [:]

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

        // Use cached image if available
        if let cached = cachedImages[status] {
            button.image = cached
            button.toolTip = "EasyTier - \(status.description)"
            return
        }

        let symbolName: String
        switch status {
        case .disconnected: symbolName = "network.slash"
        case .connecting:   symbolName = "network.connect"
        case .connected:    symbolName = "network"
        case .error:        symbolName = "exclamationmark.triangle"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "EasyTier Status") {
            // 统一使用黑白配色（template image）
            image.isTemplate = true
            cachedImages[status] = image
            button.image = image
            button.toolTip = "EasyTier - \(status.description)"
        }
    }

    /// Updates menu bar icon with color based on connection status
    func updateStatusIconColored(isRunning: Bool, hasError: Bool) {
        guard let button = statusItem?.button else { return }

        let config: String
        let color: NSColor

        if hasError {
            config = "network.badge.shield.half.filled"
            color = .systemRed
        } else if isRunning {
            config = "network.badge.shield.half.filled"
            color = .systemGreen
        } else {
            config = "network"
            color = .labelColor
        }

        if let image = NSImage(systemSymbolName: config, accessibilityDescription: "EasyTier 状态") {
            if let coloredImage = image.withSymbolConfiguration(.init(paletteColors: [color])) {
                button.image = coloredImage
                button.toolTip = "EasyTier - \(hasError ? "错误" : (isRunning ? "运行中" : "未连接"))"
            }
        }
    }

    func updateStatus(_ status: NetworkStatus, networkStatuses: [(name: String, status: NetworkStatus)] = []) {
        let snapshot = makeStatusSnapshot(status: status, networkStatuses: networkStatuses)
        if snapshot == lastStatusSnapshot {
            return
        }
        lastStatusSnapshot = snapshot

        self.networkStatuses = networkStatuses
        updateIcon(status: status)
    }

    private func makeStatusSnapshot(status: NetworkStatus, networkStatuses: [(name: String, status: NetworkStatus)]) -> String {
        let details = networkStatuses
            .map { "\($0.name):\($0.status.rawValue)" }
            .joined(separator: "|")
        return "\(status.rawValue)#\(details)"
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
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")

                // Create attributed string with colored dot
                let dotColor: NSColor
                let dotSymbol: String
                switch status {
                case .connected:
                    dotColor = .systemGreen
                    dotSymbol = "●"
                case .connecting:
                    dotColor = .systemOrange
                    dotSymbol = "●"
                case .disconnected, .error:
                    dotColor = .systemRed
                    dotSymbol = "●"
                }

                let fullText = "  \(dotSymbol) \(name): \(status.description)"
                let attributedString = NSMutableAttributedString(string: fullText)

                // Find and color the dot (first character after spaces)
                if let dotRange = fullText.range(of: dotSymbol) {
                    let nsRange = NSRange(dotRange, in: fullText)
                    attributedString.addAttribute(.foregroundColor, value: dotColor, range: nsRange)
                }

                item.attributedTitle = attributedString
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "显示主界面", action: #selector(AppDelegate.openMainWindow(_:)), keyEquivalent: ""))

        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = nil
        menu.addItem(quitItem)

        return menu
    }
}

extension AppDelegate {
    @objc func openMainWindow(_ sender: Any) {
        // Opening a window directly from an NSMenu callback is unreliable on macOS
        // until the menu has finished closing.
        DispatchQueue.main.async {
            AppDelegate.shared?.showMainWindowWithDock()
        }
    }
}
