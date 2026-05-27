import SwiftUI
import AppKit

@main
struct FloatTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("FloatText", systemImage: "text.bubble") {
            MenuBarMenu()
                .environmentObject(appDelegate.state)
                .environmentObject(appDelegate.windowManager)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    lazy var windowManager = WindowManager(appState: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        // Show every previously-persisted window.
        windowManager.showAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowManager.showAll()
        return true
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(state.hideDockIcon ? .accessory : .regular)
    }
}
