import SwiftUI
import AppKit
import Combine

enum TextAlignmentOption: String, CaseIterable, Codable {
    case left, center, right

    var nsTextAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

/// App-level state.
///
/// Holds *global* settings (alwaysOnTop, hideDockIcon, launchAtLogin) and
/// the list of windows. Per-window state lives in `WindowState`.
///
/// Commit 1 of the multi-window refactor: only one window is created in
/// practice. The collection structure is in place but unused beyond
/// `windows.first`. Subsequent commits add real multi-window plumbing.
@MainActor
final class AppState: ObservableObject {
    // MARK: Global properties
    @Published var alwaysOnTop: Bool { didSet { ud.set(alwaysOnTop, forKey: K.alwaysOnTop) } }
    @Published var hideDockIcon: Bool { didSet { ud.set(hideDockIcon, forKey: K.hideDockIcon) } }
    @Published var launchAtLogin: Bool { didSet { ud.set(launchAtLogin, forKey: K.launchAtLogin) } }

    // MARK: Windows (v0.2, still drives the visible UI as of Commit 1)
    @Published var windows: [WindowState] = []

    // MARK: v0.3 dormant model
    //
    // Added in Commit 1 of the tabbed-panel migration. These properties are
    // populated from a one-shot v0.2 → v0.3 migration but are NOT consumed
    // by the visible UI yet — that switches in Commit 2. Holding them on
    // AppState now lets the migration run in a single place and lets future
    // PanelController / TabBar code read them without further plumbing.
    @Published var panel: PanelState
    @Published var notes: [NoteState] = []
    @Published var activeNoteID: UUID?

    private let ud = UserDefaults.standard

    // MARK: Init

    init() {
        let d = UserDefaults.standard
        self.alwaysOnTop = d.object(forKey: K.alwaysOnTop) as? Bool ?? true
        self.hideDockIcon = d.object(forKey: K.hideDockIcon) as? Bool ?? false
        self.launchAtLogin = d.object(forKey: K.launchAtLogin) as? Bool ?? false
        // Placeholder PanelState (defaults read from UD; may be empty pre-migration).
        // Re-instantiated after the v3 migration writes ft.panel.* keys.
        self.panel = PanelState()

        migrateLegacyKeysIfNeeded() // v1 → v2 (existing)
        loadWindows()               // populates windows[] from v2 keys
        migrateLegacyToV3IfNeeded() // v2 → v3, dormant; uses windows[] as source
        loadV3State()               // populate panel / notes / activeNoteID from v3 keys
    }

    // MARK: Migration

    /// One-time, non-destructive migration from the v1 flat-key schema (`ft.text`,
    /// `ft.fontSize`, etc.) to the v2 per-window schema (`ft.window.<uuid>.*`).
    ///
    /// Legacy keys are NOT deleted — running an older FloatText binary after this
    /// runs will still see its previous state. A later cleanup release can
    /// remove them once we're sure no one is rolling back.
    private func migrateLegacyKeysIfNeeded() {
        if ud.bool(forKey: K.migrationV2Completed) { return }

        let legacy = LegacyKeys.self
        let hasLegacy = ud.object(forKey: legacy.text) != nil
            || ud.object(forKey: legacy.fontSize) != nil
            || ud.object(forKey: legacy.windowFrame) != nil

        if hasLegacy {
            let id = UUID()
            let prefix = "ft.window.\(id.uuidString)"

            // Copy each legacy key to the new schema (only if present).
            if let v = ud.string(forKey: legacy.text)         { ud.set(v, forKey: "\(prefix).text") }
            if let v = ud.object(forKey: legacy.fontSize)     { ud.set(v, forKey: "\(prefix).fontSize") }
            if let v = ud.string(forKey: legacy.textColorHex) { ud.set(v, forKey: "\(prefix).color") }
            if let v = ud.object(forKey: legacy.bgOpacity)    { ud.set(v, forKey: "\(prefix).opacity") }
            if let v = ud.string(forKey: legacy.alignment)    { ud.set(v, forKey: "\(prefix).alignment") }
            if let v = ud.object(forKey: legacy.isRTL)        { ud.set(v, forKey: "\(prefix).isRTL") }
            if let v = ud.object(forKey: legacy.clickThrough) { ud.set(v, forKey: "\(prefix).clickThrough") }
            if let v = ud.object(forKey: legacy.focusMode)    { ud.set(v, forKey: "\(prefix).focusMode") }
            if let v = ud.string(forKey: legacy.windowFrame)  { ud.set(v, forKey: "\(prefix).frame") }

            ud.set([id.uuidString], forKey: K.windows)
            // Legacy keys intentionally NOT removed.
        }

        ud.set(true, forKey: K.migrationV2Completed)
    }

    // MARK: Window loading

    private func loadWindows() {
        let ids = (ud.array(forKey: K.windows) as? [String] ?? []).compactMap { UUID(uuidString: $0) }
        for id in ids {
            windows.append(WindowState(id: id))
        }
        // Seed exactly one default window if nothing exists yet (fresh install
        // or a UserDefaults purge between runs).
        if windows.isEmpty {
            let seeded = WindowState(id: UUID(), useSeedText: true)
            windows.append(seeded)
            persistWindowIDs()
        }
    }

    /// Append a new WindowState and persist the updated id list.
    /// Called by WindowManager.newWindow().
    func addWindow(_ win: WindowState) {
        windows.append(win)
        persistWindowIDs()
    }

    /// Remove a window from the active set. Non-destructive by default:
    /// updates the in-memory `windows` array and the persisted `ft.windows`
    /// list so the window does NOT auto-reopen on next launch, but the
    /// per-window keys (`ft.window.<id>.text`, etc.) are LEFT IN PLACE.
    ///
    /// This is the "Close Window" semantic. A future destructive
    /// "Delete Window" would pass `keepPersistedState: false` and remove
    /// the per-window keys too.
    func removeWindow(id: UUID, keepPersistedState: Bool = true) {
        windows.removeAll { $0.id == id }
        persistWindowIDs()

        if !keepPersistedState {
            let prefix = "ft.window.\(id.uuidString)"
            let suffixes = [".text", ".fontSize", ".color", ".opacity",
                            ".alignment", ".isRTL", ".clickThrough",
                            ".focusMode", ".frame"]
            for suffix in suffixes {
                ud.removeObject(forKey: prefix + suffix)
            }
        }
    }

    /// Re-write `ft.windows` to match the current `windows` array. Internal
    /// because future commits (Close Window, Delete Window) will mutate the
    /// list too.
    func persistWindowIDs() {
        ud.set(windows.map { $0.id.uuidString }, forKey: K.windows)
    }

    // MARK: v0.2 → v0.3 migration (dormant model, non-destructive)
    //
    // Reads from the already-loaded windows[] and writes the new ft.panel.*
    // and ft.note.<uuid>.* schemas. Strict write order so a crash mid-flight
    // never leaves ft.notes pointing at note keys that don't exist yet:
    //
    //   1. per-note keys for every window  (text + createdAt + updatedAt)
    //   2. ft.notes                         (UUID array preserves window order)
    //   3. ft.activeNoteID                  (first window's id)
    //   4. ft.panel.*                       (first window's visual settings,
    //                                        clickThrough always forced false)
    //   5. ft.migration.v3.completed = true
    //
    // v0.2 keys (ft.windows, ft.window.<uuid>.*) are NOT touched — running
    // an older binary against the same defaults domain still works.
    private func migrateLegacyToV3IfNeeded() {
        if ud.bool(forKey: K.migrationV3Completed) { return }

        let sources = self.windows  // already loaded by loadWindows()

        if !sources.isEmpty {
            let nowEpoch = Date().timeIntervalSince1970

            // 1. Per-note keys first.
            for win in sources {
                let prefix = "ft.note.\(win.id.uuidString)"
                ud.set(win.text, forKey: "\(prefix).text")
                ud.set(nowEpoch, forKey: "\(prefix).createdAt")
                ud.set(nowEpoch, forKey: "\(prefix).updatedAt")
            }

            // 2. ft.notes (array order = window order).
            ud.set(sources.map { $0.id.uuidString }, forKey: K.notes)

            // 3. ft.activeNoteID = first window's id.
            ud.set(sources[0].id.uuidString, forKey: K.activeNoteID)

            // 4. ft.panel.* from first window's visual settings.
            let first = sources[0]
            ud.set(NSStringFromRect(first.windowFrame), forKey: PanelState.K.frame)
            ud.set(Double(first.fontSize), forKey: PanelState.K.fontSize)
            ud.set(first.textColorHex, forKey: PanelState.K.color)
            ud.set(first.backgroundOpacity, forKey: PanelState.K.opacity)
            ud.set(first.alignment.rawValue, forKey: PanelState.K.alignment)
            ud.set(first.isRTL, forKey: PanelState.K.isRTL)
            ud.set(first.focusMode, forKey: PanelState.K.focusMode)
            // Always start panel.clickThrough = false so the app cannot
            // relaunch in a trapped state.
            ud.set(false, forKey: PanelState.K.clickThrough)
        } else {
            // No source windows. Still ensure panel.clickThrough = false so
            // the new model never starts trapped — even on a fresh install
            // where this key wouldn't exist yet.
            ud.set(false, forKey: PanelState.K.clickThrough)
        }

        // 5. ONLY now mark migration complete.
        ud.set(true, forKey: K.migrationV3Completed)
    }

    /// Refresh in-memory v3 model from UserDefaults after migration (or on a
    /// returning launch where migration was already done previously).
    private func loadV3State() {
        // Re-instantiate PanelState so it reads the freshly-written ft.panel.*
        // values (the placeholder created in init() ran before migration).
        self.panel = PanelState()

        let ids = (ud.array(forKey: K.notes) as? [String] ?? [])
            .compactMap { UUID(uuidString: $0) }
        self.notes = ids.compactMap { NoteState(id: $0) }

        if let s = ud.string(forKey: K.activeNoteID),
           let u = UUID(uuidString: s),
           self.notes.contains(where: { $0.id == u }) {
            self.activeNoteID = u
        } else {
            self.activeNoteID = self.notes.first?.id
        }
    }

    // MARK: Keys

    enum K {
        static let alwaysOnTop = "ft.alwaysOnTop"
        static let hideDockIcon = "ft.hideDockIcon"
        static let launchAtLogin = "ft.launchAtLogin"
        static let windows = "ft.windows"
        static let migrationV2Completed = "ft.migration.v2.completed"
        // v0.3
        static let notes = "ft.notes"
        static let activeNoteID = "ft.activeNoteID"
        static let migrationV3Completed = "ft.migration.v3.completed"
    }

    private enum LegacyKeys {
        static let text = "ft.text"
        static let fontSize = "ft.fontSize"
        static let textColorHex = "ft.textColorHex"
        static let bgOpacity = "ft.bgOpacity"
        static let alignment = "ft.alignment"
        static let isRTL = "ft.isRTL"
        static let clickThrough = "ft.clickThrough"
        static let focusMode = "ft.focusMode"
        static let windowFrame = "ft.windowFrame"
    }
}

// MARK: - NSColor hex helpers (used by WindowState too)

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xff) / 255
        let g = CGFloat((v >> 8) & 0xff) / 255
        let b = CGFloat(v & 0xff) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
