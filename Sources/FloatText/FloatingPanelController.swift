import AppKit
import SwiftUI
import Combine

/// Owns one floating panel + its hosting SwiftUI tree. Per-window properties
/// (text, colors, opacity, click-through, focus mode, frame) come from
/// WindowState; global properties (alwaysOnTop) come from AppState.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate, ObservableObject {
    let appState: AppState
    let windowState: WindowState
    private weak var manager: WindowManager?
    private(set) var panel: FloatingPanel
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, windowState: WindowState, manager: WindowManager? = nil) {
        self.appState = appState
        self.windowState = windowState
        self.manager = manager
        self.panel = FloatingPanel(contentRect: windowState.windowFrame)
        super.init()
        configure()
        observeState()
    }

    private func configure() {
        let host = NSHostingView(
            rootView: OverlayView(
                windowState: windowState,
                onHide: { [weak self] in
                    guard let self = self else { return }
                    self.manager?.hideWindow(id: self.windowState.id)
                },
                onNewWindow: { [weak self] in
                    self?.manager?.newWindow()
                },
                onDelete: { [weak self] in
                    guard let self = self else { return }
                    self.manager?.deleteWindow(id: self.windowState.id)
                }
            )
        )
        // NSWindow auto-sets autoresizingMask + frame on contentView when
        // translatesAutoresizingMaskIntoConstraints is left at its default (true).
        // Do NOT set it to false here without adding replacement constraints —
        // doing so leaves the host view's frame stuck and SwiftUI hit-testing
        // uses a stale layout, so clicks fall into dead zones.
        panel.contentView = host
        panel.delegate = self
        panel.setFrame(windowState.windowFrame, display: false)
        applyAlwaysOnTop()
        applyClickThrough()
    }

    private func observeState() {
        appState.$alwaysOnTop
            .sink { [weak self] _ in self?.applyAlwaysOnTop() }
            .store(in: &cancellables)
        windowState.$clickThrough
            .sink { [weak self] _ in self?.applyClickThrough() }
            .store(in: &cancellables)
    }

    func show() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggleVisible() {
        if panel.isVisible { hide() } else { show() }
    }

    private func applyAlwaysOnTop() {
        panel.level = appState.alwaysOnTop ? .floating : .normal
    }

    private func applyClickThrough() {
        let on = windowState.clickThrough
        panel.ignoresMouseEvents = on
        if !on {
            // Restore interactivity. Two steps:
            //   1. Make the panel key so it accepts events again.
            //   2. Put first responder back on the NSTextView so the cursor
            //      is live and the user can type immediately. Without this
            //      the panel "looks normal" after disable but keystrokes go
            //      nowhere until the user manually clicks the text — the
            //      symptom that made click-through feel unreliable.
            panel.makeKeyAndOrderFront(nil)
            if let textView = FloatingPanelController.findTextView(in: panel.contentView) {
                panel.makeFirstResponder(textView)
            }
        }
    }

    private static func findTextView(in view: NSView?) -> NSTextView? {
        guard let view = view else { return nil }
        if let tv = view as? NSTextView { return tv }
        for sub in view.subviews {
            if let found = findTextView(in: sub) { return found }
        }
        return nil
    }

    // MARK: NSWindowDelegate

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    /// Track which window is "front" so menu bar commands target the right
    /// WindowState when there are multiple panels.
    nonisolated func windowDidBecomeKey(_ notification: Notification) {
        Task { @MainActor in
            self.manager?.setActive(self.windowState.id)
        }
    }

    private func captureFrame() {
        windowState.windowFrame = panel.frame
    }
}
