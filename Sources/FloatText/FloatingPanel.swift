import AppKit

/// Activating floating panel. Editable-first: NSTextView must reliably become
/// first responder, so we do NOT set .nonactivatingPanel here. See plan §"Key
/// behavioral decisions" — focus reliability beats overlay purity for MVP.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .resizable, .fullSizeContentView, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 260, height: 180)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
