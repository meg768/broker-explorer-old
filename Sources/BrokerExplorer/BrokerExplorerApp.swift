import AppKit
import SwiftUI

@main
struct BrokerExplorerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var store = ExplorerStore()

    var body: some Scene {
        Window("Broker Explorer", id: "explorer") {
            ContentView()
                .environmentObject(store)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.preferredColorScheme)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Connection") {
                Button("New Connection…", action: store.newConnection)
                    .keyboardShortcut("n")
                Menu("Open Recent") {
                    ForEach(Array(store.recentConnections.enumerated()), id: \.offset) { _, connection in
                        Button(connection.recentLabel) { store.connect(to: connection) }
                    }
                }
                .disabled(store.recentConnections.isEmpty)
                Divider()
                Button("Close Connection", action: store.disconnect)
                    .keyboardShortcut("w")
                    .disabled(store.openConnection == nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            // This app has connections, not documents or additional windows.
            if let menu = NSApp.mainMenu {
                if let file = menu.items.first(where: { $0.title == "File" }) {
                    menu.removeItem(file)
                }
                if let connection = menu.items.first(where: { $0.title == "Connection" }) {
                    menu.removeItem(connection)
                    menu.insertItem(connection, at: 1)
                }
                self.removeTabCommands(from: menu)
            }
            for window in NSApp.windows { window.tabbingMode = .disallowed }
        }
    }

    private func removeTabCommands(from menu: NSMenu) {
        let actions = ["newWindowForTab:", "toggleTabBar:", "toggleTabOverview:",
                       "mergeAllWindows:", "moveTabToNewWindow:", "selectNextTab:", "selectPreviousTab:"]
        for item in menu.items {
            if let action = item.action, actions.contains(NSStringFromSelector(action)) {
                menu.removeItem(item)
            } else if let submenu = item.submenu {
                removeTabCommands(from: submenu)
            }
        }
    }
}
