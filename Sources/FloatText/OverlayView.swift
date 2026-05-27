import SwiftUI
import AppKit

/// SwiftUI root for one floating panel. Layout (top to bottom):
///   1. Top header — window management. Left/right split so the destructive
///      action is visually isolated:
///        LEFT (destructive):
///          [trash]      Delete    — purge window + per-window UD, NSAlert confirm
///        RIGHT (safer, frequent):
///          [plus]       New Window
///          [eye.slash]  Hide      — orderOut, fully reversible
///          [eraser.fill] Clear    — wipe text only, window stays, NSAlert confirm
///      Visible when !clickThrough. Stays visible in Focus Mode so
///      management remains reachable.
///   2. RTLTextView — fills remaining space.
///   3. ControlsBar (formatting: fonts, color, alignment, RTL, focus,
///      opacity) — visible when !clickThrough AND (!focusMode || hovering).
///
/// When clickThrough is on the entire panel ignores mouse events, so both
/// bars are hidden — their absence is the visible state indicator.
struct OverlayView: View {
    @ObservedObject var windowState: WindowState
    /// Hide just this panel (orderOut). Non-destructive; restorable via
    /// 'Show All Windows'.
    var onHide: () -> Void = {}
    /// Create a new blank panel.
    var onNewWindow: () -> Void = {}
    /// Permanently delete this panel's WindowState + UserDefaults.
    /// The button shows an NSAlert before calling this.
    var onDelete: () -> Void = {}
    @State private var isHovering = false

    private var showFormatControls: Bool {
        if windowState.clickThrough { return false }
        if !windowState.focusMode { return true }
        return isHovering
    }

    private var showTopHeader: Bool { !windowState.clickThrough }

    var body: some View {
        ZStack {
            Color.black
                .opacity(windowState.backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showTopHeader {
                    topHeader
                }

                RTLTextView(
                    text: $windowState.text,
                    fontSize: windowState.fontSize,
                    textColor: windowState.textColor,
                    alignment: windowState.alignment.nsTextAlignment,
                    isRTL: windowState.isRTL
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.top, showTopHeader ? 0 : 8)

                if showFormatControls {
                    ControlsBar(windowState: windowState)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: showFormatControls)
        .animation(.easeInOut(duration: 0.15), value: showTopHeader)
    }

    private var topHeader: some View {
        HStack(spacing: 0) {
            // LEFT cluster: destructive Delete, visually isolated.
            Button(action: confirmDelete) {
                Image(systemName: "trash")
            }
            .help("Delete this window (text will be permanently removed)")
            .foregroundStyle(.red.opacity(0.85))

            Spacer(minLength: 0)

            // RIGHT cluster: safer / more frequent actions.
            HStack(spacing: 8) {
                Button(action: onNewWindow) {
                    Image(systemName: "plus")
                }
                .help("New Window")

                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                }
                .help("Hide this window (text is preserved; reopen via Show All Windows)")

                Button(action: confirmClear) {
                    Image(systemName: "eraser.fill")
                }
                .help("Clear the text in this note (window itself stays)")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func confirmDelete() {
        let alert = NSAlert()
        alert.messageText = "Delete this window?"
        alert.informativeText = "The window's text and settings will be permanently removed. Other windows are unaffected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel") // first → Return cancels
        alert.addButton(withTitle: "Delete")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            onDelete()
        }
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear this note?"
        alert.informativeText = "The text in this window will be removed. The window itself will remain."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel") // first → Return cancels
        alert.addButton(withTitle: "Clear")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            windowState.text = ""
        }
    }
}
