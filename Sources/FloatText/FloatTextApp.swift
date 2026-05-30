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
    /// Single tabbed panel (v0.3). The old WindowManager / per-window
    /// FloatingPanelController code stays on disk but is no longer
    /// instantiated.
    lazy var panelController = PanelController(appState: state)

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()

        // Empty-state safeguard: if the v3 takeover left zero notes (e.g.
        // fresh install with no prior v0.2 windows, or every note deleted
        // between sessions), seed a single blank note before showing the
        // panel so the editor always has an active tab.
        if state.notes.isEmpty {
            panelController.newTab()
        }

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
