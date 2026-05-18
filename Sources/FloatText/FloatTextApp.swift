import SwiftUI
import AppKit

@main
struct FloatTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("FloatText", systemImage: "text.bubble") {
            MenuBarMenu()
                .environmentObject(appDelegate.state)
                .environmentObject(appDelegate.panelController)
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    lazy var panelController = FloatingPanelController(state: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
        panelController.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController.show()
        return true
    }

    func applyActivationPolicy() {
        NSApp.setActivationPolicy(state.hideDockIcon ? .accessory : .regular)
    }
}
