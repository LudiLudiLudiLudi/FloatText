import SwiftUI
import AppKit

/// Two-row compact bar that fits inside a ~260px-wide panel.
/// Row 1: font size, color, alignment, RTL, focus toggle.
/// Row 2: opacity slider (full width).
struct ControlsBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    print("[FT] ControlsBar A- tapped")
                    state.fontSize = max(10, state.fontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease font size")

                Button {
                    print("[FT] ControlsBar A+ tapped")
                    state.fontSize = min(48, state.fontSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase font size")

                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: state.textColor) },
                    set: { newValue in
                        print("[FT] ControlsBar ColorPicker set")
                        let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                        state.textColorHex = ns.hexString
                    }
                ))
                .labelsHidden()
                .frame(width: 24, height: 18)
                .help("Text color")

                Picker("", selection: Binding(
                    get: { state.alignment },
                    set: {
                        print("[FT] ControlsBar Alignment Picker -> \($0)")
                        state.alignment = $0
                    }
                )) {
                    Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                    Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                    Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 84, idealWidth: 96, maxWidth: 110)

                Button {
                    print("[FT] ControlsBar RTL/LTR tapped, was \(state.isRTL)")
                    state.isRTL.toggle()
                } label: {
                    Text(state.isRTL ? "RTL" : "LTR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(width: 30)
                }
                .help("Toggle text direction")

                Button {
                    print("[FT] ControlsBar Focus toggle tapped, was \(state.focusMode)")
                    state.focusMode.toggle()
                } label: {
                    Image(systemName: state.focusMode ? "eye" : "eye.slash")
                }
                .help("Toggle Focus Mode (hide controls)")
            }

            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: Binding(
                    get: { state.backgroundOpacity },
                    set: {
                        print("[FT] ControlsBar Opacity Slider -> \($0)")
                        state.backgroundOpacity = $0
                    }
                ), in: 0.0...1.0)
                .controlSize(.mini)
                .help("Background opacity")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Color.black.opacity(0.45)
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }
}
