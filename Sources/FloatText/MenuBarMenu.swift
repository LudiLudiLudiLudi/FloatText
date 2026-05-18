import SwiftUI
import AppKit

struct MenuBarMenu: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var controller: FloatingPanelController

    var body: some View {
        Button(controller.panel.isVisible ? "Hide FloatText" : "Show FloatText") {
            controller.toggleVisible()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Divider()

        Toggle("Focus Mode (hide controls)", isOn: $state.focusMode)
            .keyboardShortcut("f", modifiers: [.command, .shift])
        Toggle("Always on Top", isOn: $state.alwaysOnTop)
        Toggle("Click-through Mode", isOn: $state.clickThrough)

        Divider()

        Toggle("RTL", isOn: $state.isRTL)
            .keyboardShortcut("r", modifiers: [.command, .shift])

        Divider()

        Toggle("Hide Dock Icon", isOn: Binding(
            get: { state.hideDockIcon },
            set: { newValue in
                state.hideDockIcon = newValue
                NSApp.setActivationPolicy(newValue ? .accessory : .regular)
                if !newValue { NSApp.activate(ignoringOtherApps: true) }
            }
        ))

        Toggle("Launch at Login", isOn: Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { newValue in
                LaunchAtLogin.set(enabled: newValue)
                state.launchAtLogin = LaunchAtLogin.isEnabled
            }
        ))

        Divider()

        Button("Quit FloatText") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
