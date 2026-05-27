import SwiftUI
import AppKit

/// Two-row compact bar that fits inside a ~260px-wide panel.
/// Row 1: font size, color, alignment, RTL, focus toggle.
/// Row 2: opacity slider (full width).
struct ControlsBar: View {
    @ObservedObject var windowState: WindowState

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Button { windowState.fontSize = max(10, windowState.fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease font size")

                Button { windowState.fontSize = min(48, windowState.fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase font size")

                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: windowState.textColor) },
                    set: { newValue in
                        let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                        windowState.textColorHex = ns.hexString
                    }
                ))
                .labelsHidden()
                .frame(width: 24, height: 18)
                .help("Text color")

                Picker("", selection: $windowState.alignment) {
                    Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                    Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                    Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 84, idealWidth: 96, maxWidth: 110)

                Button {
                    windowState.isRTL.toggle()
                } label: {
                    Text(windowState.isRTL ? "RTL" : "LTR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(width: 30)
                }
                .help("Toggle text direction")

                Button {
                    windowState.focusMode.toggle()
                } label: {
                    Image(systemName: windowState.focusMode ? "eye" : "eye.slash")
                }
                .help("Toggle Focus Mode (hide controls)")
            }

            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: $windowState.backgroundOpacity, in: 0.0...1.0)
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
