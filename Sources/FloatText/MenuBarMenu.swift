import SwiftUI
import AppKit

/// Menu bar contents for the v0.3 single tabbed panel.
///
/// Note ordering / shortcuts:
///   * Show / Hide Panel  ⌘⇧H        (dynamic — there is only one panel)
///   * New Tab            ⌘T
///   * Delete Note…                  (NSAlert; no shortcut — destructive)
///   * Clear Note…                   (NSAlert; no shortcut — destructive)
///   * Focus Mode         ⌘⇧F
///   * Always on Top  (global)
///   * Click-through Mode
///   * Disable Click-through         (rescue, only when click-through is on)
///   * RTL                ⌘⇧R
///   * Hide Dock Icon  (global)
///   * Launch at Login (global)
///   * Quit               ⌘Q
///
/// ⌘W is deliberately NOT bound in this commit per the user's spec —
/// we will revisit shortcut bindings after the tabbed UI is verified.
struct MenuBarMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var panelController: PanelController

    var body: some View {
        Button(panelController.panel.isVisible ? "Hide Panel" : "Show Panel") {
            panelController.toggleVisible()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])

        Divider()

        Button("New Tab") {
            panelController.newTab()
        }
        .keyboardShortcut("t", modifiers: .command)

        Button("Delete Note…") {
            confirmAndDeleteActive()
        }
        .disabled(appState.activeNoteID == nil)

        Button("Clear Note…") {
            confirmAndClearActive()
        }
        .disabled(appState.activeNoteID == nil)

        Divider()

        Toggle("Focus Mode", isOn: $appState.panel.focusMode)
            .keyboardShortcut("f", modifiers: [.command, .shift])

        Toggle("Always on Top", isOn: $appState.alwaysOnTop)

        Toggle("Click-through Mode", isOn: $appState.panel.clickThrough)

        // Rescue: always-available exit even if the panel is in
        // click-through and unreachable. Surfaces only when needed.
        if appState.panel.clickThrough {
            Button("Disable Click-through") {
                appState.panel.clickThrough = false
            }
        }

        Divider()

        Toggle("RTL", isOn: $appState.panel.isRTL)
            .keyboardShortcut("r", modifiers: [.command, .shift])

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

    private func confirmAndDeleteActive() {
        let alert = NSAlert()
        alert.messageText = "Delete this note?"
        alert.informativeText = "The note's text will be permanently removed. Other notes are unaffected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            panelController.deleteActiveNote()
        }
    }

    private func confirmAndClearActive() {
        let alert = NSAlert()
        alert.messageText = "Clear this note?"
        alert.informativeText = "The text in this note will be removed. The note itself will remain."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            panelController.clearActiveNote()
        }
    }
}
