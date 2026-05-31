import AppKit
import SwiftUI

/// A tiny, always-interactive control window shown ONLY while the main panel
/// is in click-through. It exists because `NSPanel.ignoresMouseEvents` is a
/// window-level property: when the main panel ignores mouse events, no view
/// inside it can receive clicks — so an in-panel "exit" badge is impossible.
/// This separate window keeps `ignoresMouseEvents = false`, so its single
/// button remains clickable and provides an on-screen escape hatch
/// (in addition to the menu-bar rescue). Structurally, this means the user
/// can never be trapped: there is always a live exit control on screen.
@MainActor
final class ClickThroughExitWindow: NSPanel {
    init(onExit: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 168, height: 30),
            // .nonactivatingPanel so clicking the button doesn't yank focus
            // away from the app the user is clicking through to.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = false      // THIS window stays interactive
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let host = NSHostingView(rootView: ExitButton(onExit: onExit))
        self.contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Position at the top-right of the given (main panel) frame and show.
    func present(over mainFrame: NSRect) {
        let margin: CGFloat = 8
        let size = self.frame.size
        let x = mainFrame.maxX - size.width - margin
        let y = mainFrame.maxY - size.height - margin
        self.setFrameOrigin(NSPoint(x: x, y: y))
        self.orderFront(nil)
    }

    func dismiss() {
        self.orderOut(nil)
    }
}

private struct ExitButton: View {
    let onExit: () -> Void

    var body: some View {
        Button(action: onExit) {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill")
                Text("Exit click-through")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(Color.black.opacity(0.78))
            )
            .overlay(
                Capsule().stroke(Color.yellow.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("Turn off click-through and restore normal interaction")
    }
}
