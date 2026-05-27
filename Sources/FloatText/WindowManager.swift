import AppKit
import SwiftUI

/// Owns the list of FloatingPanelControllers — one per WindowState.
/// Tracks which window is currently active (most recently key) so that
/// menu bar commands targeting a single window have a deterministic
/// target.
@MainActor
final class WindowManager: ObservableObject {
    let appState: AppState
    @Published private(set) var controllers: [FloatingPanelController] = []

    /// UUID of the most recently key window. Defaults to the first window
    /// on launch. Updated by FloatingPanelController.windowDidBecomeKey.
    @Published var activeWindowID: UUID?

    init(appState: AppState) {
        self.appState = appState
        for win in appState.windows {
            controllers.append(makeController(for: win))
        }
        activeWindowID = appState.windows.first?.id
    }

    // MARK: Lookups

    /// Controller for the active window, or the first controller as fallback.
    var activeController: FloatingPanelController? {
        if let id = activeWindowID,
           let match = controllers.first(where: { $0.windowState.id == id }) {
            return match
        }
        return controllers.first
    }

    var activeWindowState: WindowState? { activeController?.windowState }

    // MARK: Mutations

    /// Create a new floating panel + WindowState and make it visible.
    /// New windows do NOT use the seed Hebrew template — they start
    /// empty so they don't repeat the same boilerplate every time.
    @discardableResult
    func newWindow() -> FloatingPanelController {
        let win = WindowState(id: UUID(), useSeedText: false)

        // Offset the new frame from the last window's so they don't sit
        // exactly on top of each other.
        if let lastFrame = appState.windows.last?.windowFrame {
            var f = lastFrame
            f.origin.x += 30
            f.origin.y -= 30
            win.windowFrame = f
        }

        appState.addWindow(win)
        let c = makeController(for: win)
        controllers.append(c)
        activeWindowID = win.id
        c.show()
        return c
    }

    /// Close (non-destructive). Hides the panel, removes the controller from
    /// the active list, and tells AppState to drop the id from `ft.windows`.
    /// Per-window UserDefaults (`ft.window.<id>.*`) are LEFT IN PLACE so the
    /// user's text is never lost by closing the panel.
    func closeWindow(id: UUID) {
        guard let idx = controllers.firstIndex(where: { $0.windowState.id == id }) else { return }
        let c = controllers[idx]
        c.hide()
        controllers.remove(at: idx)
        appState.removeWindow(id: id, keepPersistedState: true)
        if activeWindowID == id {
            activeWindowID = controllers.first?.windowState.id
        }
    }

    // MARK: Visibility (acts on all windows for now)

    var anyVisible: Bool { controllers.contains { $0.panel.isVisible } }

    func showAll() { controllers.forEach { $0.show() } }
    func hideAll() { controllers.forEach { $0.hide() } }

    /// Menu-bar Show/Hide target.
    ///   * any visible            → hide all
    ///   * none visible, some exist → show all (reveal hidden)
    ///   * none exist at all      → create a fresh blank window so the user
    ///                              isn't forced to discover "New Window"
    func toggleOrCreate() {
        if anyVisible {
            hideAll()
        } else if controllers.isEmpty {
            newWindow()
        } else {
            showAll()
        }
    }

    // MARK: Key/focus tracking (called by FloatingPanelController)

    func setActive(_ id: UUID) {
        activeWindowID = id
    }

    // MARK: Internals

    private func makeController(for win: WindowState) -> FloatingPanelController {
        FloatingPanelController(appState: appState, windowState: win, manager: self)
    }
}
