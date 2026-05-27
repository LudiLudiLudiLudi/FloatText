import SwiftUI
import AppKit

/// SwiftUI root for one floating panel. Owns no state of its own beyond
/// hover; everything else lives in the WindowState the controller passes in.
struct OverlayView: View {
    @ObservedObject var windowState: WindowState
    /// Invoked by the in-window close (×) button. Wired by
    /// FloatingPanelController to WindowManager.closeWindow.
    var onClose: () -> Void = {}
    /// Invoked by the in-window + (new window) button. Wired by
    /// FloatingPanelController to WindowManager.newWindow.
    var onNewWindow: () -> Void = {}
    @State private var isHovering = false

    /// Controls policy: visible when click-through is off AND
    /// (focus mode is off OR the user is hovering the panel).
    /// They are never permanently hidden — menu bar also toggles focus.
    private var showControls: Bool {
        if windowState.clickThrough { return false }
        if !windowState.focusMode { return true }
        return isHovering
    }

    var body: some View {
        ZStack {
            // Single tint layer driven by windowState.backgroundOpacity.
            // A bare Color, not NSVisualEffectView — the slider must control
            // the real window transparency, not a darkness layer over a
            // frosted-glass material.
            Color.black
                .opacity(windowState.backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                RTLTextView(
                    text: $windowState.text,
                    fontSize: windowState.fontSize,
                    textColor: windowState.textColor,
                    alignment: windowState.alignment.nsTextAlignment,
                    isRTL: windowState.isRTL
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.top, 8)

                if showControls {
                    ControlsBar(
                        windowState: windowState,
                        onClose: onClose,
                        onNewWindow: onNewWindow
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: showControls)
    }
}
