import SwiftUI
import AppKit

/// SwiftUI root for one floating panel. Layout (top to bottom):
///   1. Top header (window management: + / ×) — visible when !clickThrough.
///      Stays visible in Focus Mode so management is always reachable.
///   2. RTLTextView — fills remaining space.
///   3. ControlsBar (formatting: fonts, color, alignment, RTL, focus,
///      opacity) — visible when !clickThrough AND (!focusMode || hovering).
///
/// When clickThrough is on the entire panel ignores mouse events, so both
/// bars are hidden — their absence is the visible state indicator.
struct OverlayView: View {
    @ObservedObject var windowState: WindowState
    /// Invoked by the top-header × button.
    var onClose: () -> Void = {}
    /// Invoked by the top-header + button.
    var onNewWindow: () -> Void = {}
    @State private var isHovering = false

    /// Bottom formatting bar policy.
    private var showFormatControls: Bool {
        if windowState.clickThrough { return false }
        if !windowState.focusMode { return true }
        return isHovering
    }

    /// Top window-management bar policy. Independent of focus mode so
    /// management remains accessible even when formatting controls are
    /// hidden. Suppressed when click-through is on (panel is passive then).
    private var showTopHeader: Bool {
        !windowState.clickThrough
    }

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
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            Button(action: onNewWindow) {
                Image(systemName: "plus")
            }
            .help("New Window")

            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .help("Close this window (text is preserved)")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
