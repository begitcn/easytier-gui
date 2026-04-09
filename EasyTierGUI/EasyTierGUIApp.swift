import SwiftUI

@main
struct EasyTierGUIApp: App {
    @StateObject private var processVM = ProcessViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register default values for AppStorage
        UserDefaults.standard.register(defaults: [
            "showDockIcon": true,
            "showMenuBar": true
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(processVM)
                .frame(minWidth: 700, minHeight: 500)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    processVM.forceStopAllSync()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
                    let autoConnect = UserDefaults.standard.bool(forKey: "autoConnectOnLaunch")
                    if autoConnect {
                        Task {
                            // Short delay to let the UI settle before connecting
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            await processVM.connect()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    if let window = notification.object as? NSWindow, window.isKeyWindow {
                        // When the main window closes, check if we should hide the Dock icon
                        let showDock = UserDefaults.standard.bool(forKey: "showDockIcon")
                        if !showDock {
                            AppDelegate.shared?.setDockIconVisible(false)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("关于 EasyTier") {
                    NSApplication.shared.orderFrontStandardAboutPanel(nil)
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(processVM)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Only terminate if the Dock icon is visible, or if the user explicitly quits
        // If dock icon is hidden, we keep the app running in the background (Menu Bar)
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // Create menu bar icon
        MenuBarManager.shared.setupMenuBar()
        checkRootPrivileges()

        // Application starts with window visible, so ensure it's in .regular mode initially
        // regardless of preference, because the Dock icon should be visible while window is open.
        setDockIconVisible(true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindowWithDock()
        }
        return true
    }

    func showMainWindowWithDock() {
        setDockIconVisible(true)
        DispatchQueue.main.async {
            NSApp.unhide(nil)
            if let window = NSApplication.shared.windows.first {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func setDockIconVisible(_ visible: Bool) {
        DispatchQueue.main.async {
            if visible {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    private func checkRootPrivileges() {
        // Check if running as root (uid 0)
        let uid = getuid()
        if uid != 0 {
            // Not running as root, show authorization dialog
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestRootPrivileges()
            }
        }
    }

    private func requestRootPrivileges() {
        let alert = NSAlert()
        alert.messageText = "需要管理员权限"
        alert.informativeText = "EasyTier 需要 root 权限才能创建 TUN 网络设备。\n\n点击\"授权\"后会请求一次管理员密码，并在当前应用内建立管理员会话。之后连接和断开都不再重复弹出密码框，也不会重启应用。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "授权")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            authorizeCurrentSession()
        } else {
            // User cancelled, show info about limited functionality
            showLimitedFunctionalityWarning()
        }
    }

    private func authorizeCurrentSession() {
        do {
            try PrivilegedSessionManager.shared.ensureAuthorized()
        } catch {
            print("Failed to authorize current session: \(error)")
            showAuthorizationError(message: error.localizedDescription)
        }
    }

    private func showAuthorizationError(message: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "授权失败"
            alert.informativeText = """
            \(message ?? "无法获取管理员权限。")\n
            请尝试以下方式：

            1. 从终端运行：
               sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI

            2. 使用启动脚本：
               ./launch-easytier-gui.sh

            详细说明请参考 RUN-WITH-SUDO.md 文档。
            """
            alert.alertStyle = .critical
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }
    }

    private func showLimitedFunctionalityWarning() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "功能受限"
            alert.informativeText = """
            未获取管理员权限，EasyTier 将无法创建 TUN 设备。

            如需完整功能，请重新启动应用并完成授权，
            或使用以下命令重新运行：
            sudo /Applications/EasyTierGUI.app/Contents/MacOS/EasyTierGUI
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        }
    }
}
