import SwiftUI
import AppKit

struct OverlayView: View {
    @EnvironmentObject var state: AppState
    @State private var isHovering = false

    /// Controls policy: visible when click-through is off AND
    /// (focus mode is off OR the user is hovering the panel).
    /// They are never permanently hidden — menu bar also toggles focus.
    private var showControls: Bool {
        if state.clickThrough { return false }
        if !state.focusMode { return true }
        return isHovering
    }

    var body: some View {
        ZStack {
            // Single tint layer driven by state.backgroundOpacity.
            // A bare Color, not NSVisualEffectView — the slider must control
            // the real window transparency, not a darkness layer over a
            // frosted-glass material.
            Color.black
                .opacity(state.backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                RTLTextView(
                    text: $state.text,
                    fontSize: state.fontSize,
                    textColor: state.textColor,
                    alignment: state.alignment.nsTextAlignment,
                    isRTL: state.isRTL
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.top, 8)

                if showControls {
                    ControlsBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: showControls)
    }
}
