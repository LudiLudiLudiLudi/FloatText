import SwiftUI
import AppKit

/// Bottom formatting / reading bar. Two rows, compact enough to fit in a
/// ~260 px-wide panel:
///   Row 1: A-, A+, color, alignment, RTL, focus toggle.
///   Row 2: opacity slider.
///
/// All settings are PANEL-WIDE for v0.3 MVP (per the user's spec): font
/// size, color, alignment, RTL direction, focus mode, and background
/// opacity apply to whichever note tab is currently active and to all
/// other tabs equally. Per-tab visuals are a future enhancement.
///
/// Window-management controls (`+` new tab, `×` close, `🧹` clear) live
/// in OverlayView's top header, not here, so they stay reachable in
/// Focus Mode.
struct ControlsBar: View {
    @ObservedObject var panel: PanelState

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Button { panel.fontSize = max(10, panel.fontSize - 1) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease font size")

                Button { panel.fontSize = min(48, panel.fontSize + 1) } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase font size")

                ColorPicker("", selection: Binding(
                    get: { Color(nsColor: panel.textColor) },
                    set: { newValue in
                        let ns = NSColor(newValue).usingColorSpace(.sRGB) ?? .white
                        panel.textColorHex = ns.hexString
                    }
                ))
                .labelsHidden()
                .frame(width: 24, height: 18)
                .help("Text color")

                Picker("", selection: $panel.alignment) {
                    Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                    Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                    Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(minWidth: 84, idealWidth: 96, maxWidth: 110)

                Button {
                    panel.isRTL.toggle()
                } label: {
                    Text(panel.isRTL ? "RTL" : "LTR")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(width: 30)
                }
                .help("Toggle text direction")

                Button {
                    panel.focusMode.toggle()
                } label: {
                    Image(systemName: panel.focusMode ? "eye" : "eye.slash")
                }
                .help("Toggle Focus Mode (hide formatting controls)")
            }

            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundStyle(.white.opacity(0.6))
                Slider(value: $panel.backgroundOpacity, in: 0.0...1.0)
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
