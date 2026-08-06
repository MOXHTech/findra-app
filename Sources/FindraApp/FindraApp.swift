import AppKit
import SwiftUI

@main
struct FindraApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var lifecycleDelegate
    @StateObject private var appModel = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Findra", id: "search") {
            SearchView(model: appModel.search)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear {
                    lifecycleDelegate.configure(daemon: appModel.daemon)
                    appModel.statusItem.configure {
                        appModel.showSearchWindow {
                            openWindow(id: "search")
                        }
                    }
                    appModel.hotKey.start {
                        appModel.showSearchWindow {
                            openWindow(id: "search")
                        }
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Findra") {
                Button("Search") {
                    appModel.showSearchWindow {
                        openWindow(id: "search")
                    }
                }
                .keyboardShortcut(" ", modifiers: [.option])
            }
        }

        Settings {
            PreferencesView(model: appModel.preferences)
        }

    }
}

@MainActor
final class AppModel: ObservableObject {
    let daemon: DaemonClient
    let search: SearchViewModel
    let preferences: PreferencesViewModel
    let hotKey = HotKeyCenter()
    let statusItem = StatusItemController()

    init(daemon: DaemonClient = SocketDaemonClient()) {
        self.daemon = daemon
        self.preferences = PreferencesViewModel()
        self.search = SearchViewModel(daemon: daemon, preferences: preferences)
    }

    func showSearchWindow(openWindow: () -> Void) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Findra" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow()
        }
    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    private var daemon: DaemonClient?
    private var isTerminating = false

    func configure(daemon: DaemonClient) {
        self.daemon = daemon
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else {
            return .terminateNow
        }
        guard let daemon else {
            return .terminateNow
        }

        isTerminating = true
        Task {
            try? await daemon.stopDaemon()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func windowWillClose() {
        DispatchQueue.main.async {
            guard NSApplication.shared.windows.allSatisfy({ !$0.isVisible }) else { return }
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
