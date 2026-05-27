import SwiftUI
import AppKit

@main
struct FloatTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("FloatText", systemImage: "text.bubble") {
            MenuBarMenu()
                .environmentObject(appDelegate.state)
                .environmentObject(appDelegate.primaryController)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    /// First (and currently only) controller. Future commits introduce a
    /// WindowManager that owns the full collection.
    lazy var primaryController: FloatingPanelController = {
        guard let win = state.windows.first else {
            fatalError("AppState should always seed at least one WindowState")
        }
        return FloatingPanelController(appState: state, windowState: win)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        primaryController.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        primaryController.show()
        return true
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(state.hideDockIcon ? .accessory : .regular)
    }
}
