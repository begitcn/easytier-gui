import SwiftUI

@main
struct EasyTierGUIApp: App {
    @StateObject private var processVM = ProcessViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(processVM)
                .frame(minWidth: 700, minHeight: 500)
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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar icon
        MenuBarManager.shared.setupMenuBar()
        checkRootPrivileges()
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
