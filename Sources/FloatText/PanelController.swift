import AppKit
import SwiftUI
import Combine

/// Single floating panel + tab routing (v0.3). Owns the one FloatingPanel,
/// the click-through exit window, and the note-tab actions.
@MainActor
final class PanelController: NSObject, NSWindowDelegate, ObservableObject {
    let appState: AppState
    private(set) var panel: FloatingPanel
    private var cancellables = Set<AnyCancellable>()

    /// On-screen escape hatch shown only while click-through is on.
    private lazy var exitWindow = ClickThroughExitWindow { [weak self] in
        self?.forceDisableClickThrough()
    }

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
                panel: appState.panel,
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
        // At init the stored value is already settled (no willSet in flight),
        // so reading it directly here is correct.
        applyClickThrough(appState.panel.clickThrough)
    }

    private func observeState() {
        appState.$alwaysOnTop
            .sink { [weak self] _ in self?.applyAlwaysOnTop() }
            .store(in: &cancellables)
        // IMPORTANT: @Published fires its publisher in willSet — the stored
        // property is NOT yet updated when this closure runs. We must use the
        // delivered `newValue`, never re-read appState.panel.clickThrough
        // (that returns the OLD value and inverts every toggle, which caused
        // the click-through stuck-panel bug).
        appState.panel.$clickThrough
            .sink { [weak self] newValue in self?.applyClickThrough(newValue) }
            .store(in: &cancellables)
    }

    // MARK: Show / Hide

    func show() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        exitWindow.dismiss()
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

        // New tab inherits the CURRENTLY ACTIVE note's color so it visually
        // matches what the user was just working in (least-surprising in a
        // tabbed workflow). Falls back to a safe default when there's no
        // active note.
        let inheritedColor = appState.notes
            .first { $0.id == appState.activeNoteID }?
            .textColorHex ?? "#F2F2F2"

        // Per-note keys FIRST (same write-order discipline as the migration).
        let ud = UserDefaults.standard
        ud.set("", forKey: "\(prefix).text")
        ud.set(nowEpoch, forKey: "\(prefix).createdAt")
        ud.set(nowEpoch, forKey: "\(prefix).updatedAt")
        ud.set(inheritedColor, forKey: "\(prefix).color")

        // Then append + activate (also persists ft.notes + ft.activeNoteID).
        let note = NoteState(id: id, text: "", createdAt: now, updatedAt: now,
                             textColorHex: inheritedColor)
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

    /// Apply click-through. `on` MUST be the authoritative new value — passed
    /// in by the caller, never re-read from appState.panel.clickThrough during
    /// a willSet-driven Combine callback (see observeState).
    private func applyClickThrough(_ on: Bool) {
        // ignoresMouseEvents is an AppKit property; mutate on the main thread.
        // PanelController is @MainActor and all callers are main-thread, so
        // this is already safe — kept explicit for clarity.
        panel.ignoresMouseEvents = on
        if on {
            // Show the separate, always-interactive exit control over the main
            // panel's top-right corner. The main panel can't be dragged while
            // it ignores mouse events, so positioning once on show is enough.
            exitWindow.present(over: panel.frame)
        } else {
            // Full interactivity restore: accept events, become key, reactivate
            // the app, and put the caret back in the text view so the user can
            // immediately type AND drag the window again.
            exitWindow.dismiss()
            panel.ignoresMouseEvents = false
            panel.isMovableByWindowBackground = true
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let textView = Self.findTextView(in: panel.contentView) {
                panel.makeFirstResponder(textView)
            }
        }
    }

    /// Force click-through fully OFF regardless of current state. Used by the
    /// menu-bar rescue path so the user can never be trapped.
    func forceDisableClickThrough() {
        appState.panel.clickThrough = false   // publishes → applyClickThrough(false)
        applyClickThrough(false)              // belt-and-suspenders, idempotent
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
