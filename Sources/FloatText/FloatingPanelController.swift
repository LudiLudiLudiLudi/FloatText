import AppKit
import SwiftUI
import Combine

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate, ObservableObject {
    let state: AppState
    private(set) var panel: FloatingPanel
    private var cancellables = Set<AnyCancellable>()

    init(state: AppState) {
        self.state = state
        self.panel = FloatingPanel(contentRect: state.windowFrame)
        super.init()
        configure()
        observeState()
    }

    private func configure() {
        let host = NSHostingView(rootView: OverlayView().environmentObject(state))
        // NSWindow auto-sets autoresizingMask + frame on contentView when
        // translatesAutoresizingMaskIntoConstraints is left at its default (true).
        // Do NOT set it to false here without adding replacement constraints —
        // doing so leaves the host view's frame stuck and SwiftUI hit-testing
        // uses a stale layout, so clicks fall into dead zones.
        panel.contentView = host
        panel.delegate = self
        panel.setFrame(state.windowFrame, display: false)
        applyAlwaysOnTop()
        applyClickThrough()
    }

    private func observeState() {
        state.$alwaysOnTop
            .sink { [weak self] _ in self?.applyAlwaysOnTop() }
            .store(in: &cancellables)
        state.$clickThrough
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
        panel.level = state.alwaysOnTop ? .floating : .normal
    }

    private func applyClickThrough() {
        panel.ignoresMouseEvents = state.clickThrough
    }

    // MARK: NSWindowDelegate

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    private func captureFrame() {
        state.windowFrame = panel.frame
    }
}
