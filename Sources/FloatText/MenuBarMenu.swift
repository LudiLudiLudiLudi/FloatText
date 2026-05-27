import SwiftUI
import AppKit

/// Menu bar contents. Per-window items target the currently-active window
/// (`windowManager.activeWindowState`); global items target AppState.
struct MenuBarMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var windowManager: WindowManager

    /// The window currently targeted by per-window menu commands.
    private var activeWindow: WindowState? { windowManager.activeWindowState }

    var body: some View {
        Button("Show All Windows") {
            windowManager.showAllOrCreate()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Button("Hide All Windows") {
            windowManager.hideAll()
        }
        .disabled(!windowManager.anyVisible)

        Button("New Window") {
            windowManager.newWindow()
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("Hide Current Window") {
            if let id = windowManager.activeWindowID {
                windowManager.hideWindow(id: id)
            }
        }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(windowManager.activeWindowID == nil)

        Button("Delete Current Window…") {
            if let id = windowManager.activeWindowID {
                confirmAndDeleteWindow(id: id)
            }
        }
        .disabled(windowManager.activeWindowID == nil)

        Divider()

        if let win = activeWindow {
            Toggle("Focus Mode (hide controls)", isOn: Binding(
                get: { win.focusMode },
                set: { win.focusMode = $0 }
            ))
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        Toggle("Always on Top", isOn: $appState.alwaysOnTop)

        if let win = activeWindow {
            Toggle("Click-through Mode", isOn: Binding(
                get: { win.clickThrough },
                set: { win.clickThrough = $0 }
            ))
        }

        // Rescue path: surfaced only when some window is in click-through.
        // Guarantees a no-trap-state exit in multi-window setups where the
        // active window's toggle may target a different panel than the one
        // that's actually stuck.
        if windowManager.anyClickThrough {
            Button("Disable Click-through (All Windows)") {
                windowManager.disableClickThroughOnAll()
            }
        }

        Divider()

        if let win = activeWindow {
            Toggle("RTL", isOn: Binding(
                get: { win.isRTL },
                set: { win.isRTL = $0 }
            ))
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        Divider()

        Toggle("Hide Dock Icon", isOn: Binding(
            get: { appState.hideDockIcon },
            set: { newValue in
                appState.hideDockIcon = newValue
                NSApp.setActivationPolicy(newValue ? .accessory : .regular)
                if !newValue { NSApp.activate(ignoringOtherApps: true) }
            }
        ))

        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { newValue in
                LaunchAtLogin.set(enabled: newValue)
                appState.launchAtLogin = LaunchAtLogin.isEnabled
            }
        ))

        Divider()

        Button("Quit FloatText") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Same confirmation copy as the in-window trash button. Belt-and-suspenders:
    /// the action is explicitly labelled 'Delete...' AND requires confirmation.
    private func confirmAndDeleteWindow(id: UUID) {
        let alert = NSAlert()
        alert.messageText = "Delete this window?"
        alert.informativeText = "The window's text and settings will be permanently removed. Other windows are unaffected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            windowManager.deleteWindow(id: id)
        }
    }
}
