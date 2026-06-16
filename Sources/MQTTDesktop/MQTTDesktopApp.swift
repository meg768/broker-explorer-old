import SwiftUI

@main
struct MQTTDesktopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
        }
    }
}

