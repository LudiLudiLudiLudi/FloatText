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
        Button(windowManager.anyVisible ? "Hide FloatText" : "Show FloatText") {
            windowManager.toggleOrCreate()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Button("New Window") {
            windowManager.newWindow()
        }
        .keyboardShortcut("n", modifiers: .command)

        Button("Close Window") {
            if let id = windowManager.activeWindowID {
                windowManager.closeWindow(id: id)
            }
        }
        .keyboardShortcut("w", modifiers: .command)
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
}
