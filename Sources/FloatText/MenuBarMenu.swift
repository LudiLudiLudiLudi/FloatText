import SwiftUI
import AppKit

/// Menu bar contents. For Commit 1 the menu still acts on a single window —
/// `appState.windows.first`. Future commits add New / Close / per-window
/// targeting.
struct MenuBarMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var controller: FloatingPanelController

    private var windowState: WindowState? { appState.windows.first }

    var body: some View {
        Button(controller.panel.isVisible ? "Hide FloatText" : "Show FloatText") {
            controller.toggleVisible()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Divider()

        if let win = windowState {
            Toggle("Focus Mode (hide controls)", isOn: Binding(
                get: { win.focusMode },
                set: { win.focusMode = $0 }
            ))
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        Toggle("Always on Top", isOn: $appState.alwaysOnTop)

        if let win = windowState {
            Toggle("Click-through Mode", isOn: Binding(
                get: { win.clickThrough },
                set: { win.clickThrough = $0 }
            ))
        }

        Divider()

        if let win = windowState {
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
