import SwiftUI

private struct MainWindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

private struct MainWindowSceneBridge: View {
    @Environment(\.openWindow) private var openWindow
    let onResolve: (@escaping () -> Void) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                onResolve {
                    openWindow(id: "main")
                }
            }
    }
}

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
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(processVM)
                .frame(minWidth: 700, minHeight: 500)
                .background(
                    MainWindowAccessor { window in
                        appDelegate.configureMainWindow(window)
                    }
                )
                .overlay(
                    MainWindowSceneBridge { openAction in
                        appDelegate.setOpenMainWindowAction(openAction)
                    }
                )
                .onAppear {
                    appDelegate.processVM = processVM
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
        .defaultSize(width: 800, height: 600)
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
    var processVM: ProcessViewModel?
    private let mainWindowDelegate = MainWindowDelegate()
    private weak var mainWindow: NSWindow?
    private var openMainWindowAction: (() -> Void)?

    func applicationWillTerminate(_ notification: Notification) {
        // Stop all background processes synchronously on exit
        processVM?.forceStopAllSync()
    }

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
        showMainWindowWithDock()
        return true
    }

    func showMainWindowWithDock() {
        // Make sure we're on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.showMainWindowWithDock()
            }
            return
        }

        // Switching from accessory to regular is not instantaneous on macOS.
        // Restoring the window too early can leave the app activated in the Dock
        // while the SwiftUI window stays hidden until the Dock icon is clicked.
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.restoreMainWindow()
        }
    }

    func setOpenMainWindowAction(_ action: @escaping () -> Void) {
        openMainWindowAction = action
    }

    private func openMainWindowScene() {
        if let openMainWindowAction {
            openMainWindowAction()
        }
    }

    private func restoreMainWindow() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.restoreMainWindow()
            }
            return
        }

        NSRunningApplication.current.activate(options: .activateAllWindows)
        NSApp.activate(ignoringOtherApps: true)

        if let window = resolvedMainWindow() {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.setIsVisible(true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            mainWindow = window
            NSRunningApplication.current.activate(options: .activateAllWindows)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        openMainWindowScene()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if let window = self.resolvedMainWindow() {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }

                window.setIsVisible(true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                self.mainWindow = window
            }

            NSRunningApplication.current.activate(options: .activateAllWindows)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func configureMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else { return }
        mainWindow = window
        mainWindowDelegate.appDelegate = self
        window.delegate = mainWindowDelegate
        window.isReleasedWhenClosed = false
    }

    fileprivate func handleMainWindowClose(_ window: NSWindow) -> Bool {
        let showDock = UserDefaults.standard.bool(forKey: "showDockIcon")
        guard !showDock else { return true }

        window.orderOut(nil)
        setDockIconVisible(false)
        return false
    }

    private func resolvedMainWindow() -> NSWindow? {
        if let mainWindow, !mainWindow.isSheet {
            return mainWindow
        }

        if let window = NSApplication.shared.windows.first(where: { !$0.isSheet && $0.contentView != nil }) {
            mainWindow = window
            return window
        }

        return nil
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
            // Not running as root, directly request authorization (will show password dialog)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.authorizeCurrentSession()
            }
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

}

private final class MainWindowDelegate: NSObject, NSWindowDelegate {
    weak var appDelegate: AppDelegate?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        appDelegate?.handleMainWindowClose(sender) ?? true
    }
}
