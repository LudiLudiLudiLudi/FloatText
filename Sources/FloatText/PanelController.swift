import AppKit
import SwiftUI
import Combine

/// Single floating panel + tab routing. Replaces the v0.2
/// `WindowManager` + per-window `FloatingPanelController` for the visible
/// UI in Commit 2 of the tabbed-panel migration. The old files remain on
/// disk but no one instantiates them anymore.
@MainActor
final class PanelController: NSObject, NSWindowDelegate, ObservableObject {
    let appState: AppState
    private(set) var panel: FloatingPanel
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.panel = FloatingPanel(contentRect: appState.panel.windowFrame)
        super.init()
        configure()
        observeState()
    }

    private func configure() {
        let host = NSHostingView(
            rootView: OverlayView(
                appState: appState,
                onHide: { [weak self] in self?.hide() },
                onNewTab: { [weak self] in self?.newTab() },
                onDeleteNote: { [weak self] in self?.deleteActiveNote() },
                onClearNote: { [weak self] in self?.clearActiveNote() }
            )
        )
        // NSWindow auto-sets the contentView's autoresizing mask + frame when
        // translatesAutoresizingMaskIntoConstraints is left at its default.
        // Do not set it to false here without replacement constraints — that
        // bug from v0.2 left the host frame stale and broke hit-testing.
        panel.contentView = host
        panel.delegate = self
        panel.setFrame(appState.panel.windowFrame, display: false)
        applyAlwaysOnTop()
        applyClickThrough()
    }

    private func observeState() {
        appState.$alwaysOnTop
            .sink { [weak self] _ in self?.applyAlwaysOnTop() }
            .store(in: &cancellables)
        appState.panel.$clickThrough
            .sink { [weak self] _ in self?.applyClickThrough() }
            .store(in: &cancellables)
    }

    // MARK: Show / Hide

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

    // MARK: Tab actions

    /// Create a new blank note, persist it, and switch to it. New tabs do
    /// NOT use the Hebrew seed text — they start empty so they don't
    /// repeat boilerplate.
    func newTab() {
        let id = UUID()
        let now = Date()
        let nowEpoch = now.timeIntervalSince1970
        let prefix = "ft.note.\(id.uuidString)"

        // Per-note keys FIRST (same write-order discipline as the migration).
        let ud = UserDefaults.standard
        ud.set("", forKey: "\(prefix).text")
        ud.set(nowEpoch, forKey: "\(prefix).createdAt")
        ud.set(nowEpoch, forKey: "\(prefix).updatedAt")

        // Then append + activate (also persists ft.notes + ft.activeNoteID).
        let note = NoteState(id: id, text: "", createdAt: now, updatedAt: now)
        appState.appendNote(note)
    }

    /// Delete the current note with confirmation handled by the caller
    /// (OverlayView's trash button + MenuBarMenu both show an NSAlert
    /// before invoking this). If this was the last note, a fresh blank
    /// note is created so the panel never has zero tabs.
    func deleteActiveNote() {
        guard let id = appState.activeNoteID else { return }
        appState.deleteNote(id: id)
        if appState.notes.isEmpty {
            newTab()
        }
    }

    /// Wipe just the active note's text. The note itself remains.
    /// Confirmation handled by the caller.
    func clearActiveNote() {
        guard let id = appState.activeNoteID,
              let note = appState.notes.first(where: { $0.id == id }) else { return }
        note.text = ""
    }

    // MARK: Panel mode

    private func applyAlwaysOnTop() {
        panel.level = appState.alwaysOnTop ? .floating : .normal
    }

    private func applyClickThrough() {
        let on = appState.panel.clickThrough
        panel.ignoresMouseEvents = on
        if !on {
            panel.makeKeyAndOrderFront(nil)
            if let textView = Self.findTextView(in: panel.contentView) {
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

    private func captureFrame() {
        appState.panel.windowFrame = panel.frame
    }
}
