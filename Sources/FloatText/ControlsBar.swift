import SwiftUI
import AppKit

struct ControlsBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            Button { state.fontSize = max(10, state.fontSize - 1) } label: {
                Image(systemName: "textformat.size.smaller")
            }
            .help("Decrease font size")

            Button { state.fontSize = min(48, state.fontSize + 1) } label: {
                Image(systemName: "textformat.size.larger")
            }
            .help("Increase font size")

            Divider().frame(height: 14)

            ColorPicker("", selection: Binding(
                get: { Color(nsColor: state.textColor) },
                set: { newValue in
                    let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                    state.textColorHex = ns.hexString
                }
            ))
            .labelsHidden()
            .frame(width: 28, height: 18)
            .help("Text color")

            Divider().frame(height: 14)

            Slider(value: $state.backgroundOpacity, in: 0.0...1.0)
                .frame(width: 90)
                .help("Background opacity")

            Divider().frame(height: 14)

            Picker("", selection: $state.alignment) {
                Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 110)

            Divider().frame(height: 14)

            Button {
                state.isRTL.toggle()
            } label: {
                Text(state.isRTL ? "RTL" : "LTR")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .frame(width: 32)
            }
            .help("Toggle text direction")

            Spacer(minLength: 0)

            Button {
                state.focusMode.toggle()
            } label: {
                Image(systemName: state.focusMode ? "eye" : "eye.slash")
            }
            .help("Toggle Focus Mode (hide controls)")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
    }
}
