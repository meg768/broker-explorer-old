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
            CommandGroup(replacing: .help) {
                Button("Broker Explorer Help") {
                    let alert = NSAlert()
                    alert.messageText = "Broker Explorer Help is a work in progress."
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
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
    private var menuObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        menuObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didAddItemNotification, object: nil, queue: .main
        ) { notification in
            guard let menu = notification.object as? NSMenu, menu === NSApp.mainMenu else { return }
            DispatchQueue.main.async { self.configureMenuBar() }
        }
        DispatchQueue.main.async {
            self.configureMenuBar()
            for window in NSApp.windows { window.tabbingMode = .disallowed }
        }
    }

    private func configureMenuBar() {
        guard let menu = NSApp.mainMenu else { return }
        for item in menu.items where ["File", "View", "Window"].contains(item.title) {
            menu.removeItem(item)
        }
        if let connection = menu.items.first(where: { $0.title == "Connection" }),
           menu.index(of: connection) != 1 {
            menu.removeItem(connection)
            menu.insertItem(connection, at: 1)
        }
        removeTabCommands(from: menu)
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
