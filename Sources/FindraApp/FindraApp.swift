import AppKit
import SwiftUI

@main
struct FindraApp: App {
    @StateObject private var appModel = AppModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Findra", id: "search") {
            SearchView(model: appModel.search)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear {
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
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.title == "Findra" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow()
        }
    }
}
