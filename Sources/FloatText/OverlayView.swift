import SwiftUI
import AppKit

struct OverlayView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                .ignoresSafeArea()
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
                .padding(.horizontal, 4)
                .padding(.top, 8)

                if !state.focusMode && !state.clickThrough {
                    ControlsBar()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: state.focusMode)
        .animation(.easeInOut(duration: 0.15), value: state.clickThrough)
    }
}
