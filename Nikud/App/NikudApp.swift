import SwiftUI

enum WindowID {
    static let settings = "nikud-settings"
}

@main
struct NikudApp: App {
    @StateObject private var env = AppEnvironment()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(env)
                .environmentObject(env.preferences)
                .environmentObject(env.models)
        } label: {
            Image(systemName: "text.badge.checkmark")
        }
        .menuBarExtraStyle(.window)

        Window("Nikud Settings", id: WindowID.settings) {
            SettingsWindow()
                .environmentObject(env)
                .environmentObject(env.preferences)
                .environmentObject(env.models)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}
