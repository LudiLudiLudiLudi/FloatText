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
    private(set) var panel: FloatingPanel
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState, windowState: WindowState) {
        self.appState = appState
        self.windowState = windowState
        self.panel = FloatingPanel(contentRect: windowState.windowFrame)
        super.init()
        configure()
        observeState()
    }

    private func configure() {
        let host = NSHostingView(
            rootView: OverlayView(windowState: windowState)
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
        panel.ignoresMouseEvents = windowState.clickThrough
    }

    // MARK: NSWindowDelegate

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in self.captureFrame() }
    }

    private func captureFrame() {
        windowState.windowFrame = panel.frame
    }
}
