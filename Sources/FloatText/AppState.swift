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

        migrateLegacyKeysIfNeeded()      // v1 → v2 (existing)
        loadWindows()                    // populates windows[] from v2 keys
        migrateLegacyToV3IfNeeded()      // v2 → v3, dormant snapshot (Commit 1)
        performV3TakeoverIfNeeded()      // v2 → v3 refresh on first tabbed UI launch (Commit 2)
        loadV3State()                    // populate panel / notes / activeNoteID from v3 keys
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

    /// v0.3 takeover: refresh on the first launch of the tabbed UI. The
    /// Commit-1 snapshot may be stale (the user may have edited text in the
    /// v0.2 UI between Commit 1 and Commit 2), so this step copies the
    /// LATEST `ft.window.<uuid>.text` into `ft.note.<uuid>.text` before
    /// the tabbed UI is shown for the first time.
    ///
    /// Gated on `ft.migration.v3.takeoverCompleted` so it runs at most once.
    /// Non-destructive: v0.2 keys are READ, never modified or deleted.
    ///
    /// Strict write order is the same as the dormant migration. The flag is
    /// only set after all per-note keys, ft.notes, ft.activeNoteID,
    /// ft.panel.*, and ft.panel.clickThrough=false have been written. A
    /// crash anywhere before the flag means the next launch retries safely.
    private func performV3TakeoverIfNeeded() {
        if ud.bool(forKey: K.migrationV3TakeoverCompleted) { return }

        let sourceUUIDs = (ud.array(forKey: K.windows) as? [String] ?? [])
            .compactMap { UUID(uuidString: $0) }

        if !sourceUUIDs.isEmpty {
            let nowEpoch = Date().timeIntervalSince1970

            // 1. Per-note keys: refresh text from LATEST v0.2 text. Preserve
            //    Commit-1's createdAt if it exists (best timestamp we have).
            //    Always bump updatedAt.
            for id in sourceUUIDs {
                let v2Prefix = "ft.window.\(id.uuidString)"
                let v3Prefix = "ft.note.\(id.uuidString)"
                let latestText = ud.string(forKey: "\(v2Prefix).text") ?? ""
                ud.set(latestText, forKey: "\(v3Prefix).text")
                if ud.object(forKey: "\(v3Prefix).createdAt") == nil {
                    ud.set(nowEpoch, forKey: "\(v3Prefix).createdAt")
                }
                ud.set(nowEpoch, forKey: "\(v3Prefix).updatedAt")
            }

            // 2. ft.notes: overwrite with current ft.windows (handles
            //    additions / deletions / reorderings made after Commit 1).
            ud.set(sourceUUIDs.map { $0.uuidString }, forKey: K.notes)

            // 3. ft.activeNoteID: keep the existing value if it still points
            //    at one of the current source UUIDs; otherwise fall back to
            //    the first one.
            let currentActive = ud.string(forKey: K.activeNoteID).flatMap { UUID(uuidString: $0) }
            if let active = currentActive, sourceUUIDs.contains(active) {
                // unchanged
            } else {
                ud.set(sourceUUIDs[0].uuidString, forKey: K.activeNoteID)
            }

            // 4. ft.panel.*: refresh from the LATEST first-window visuals.
            //    Catches any visual tweaks the user made after Commit 1.
            let firstID = sourceUUIDs[0]
            let v2Prefix = "ft.window.\(firstID.uuidString)"
            if let v = ud.string(forKey: "\(v2Prefix).frame")     { ud.set(v, forKey: PanelState.K.frame) }
            if let v = ud.object(forKey: "\(v2Prefix).fontSize")  { ud.set(v, forKey: PanelState.K.fontSize) }
            if let v = ud.string(forKey: "\(v2Prefix).color")     { ud.set(v, forKey: PanelState.K.color) }
            if let v = ud.object(forKey: "\(v2Prefix).opacity")   { ud.set(v, forKey: PanelState.K.opacity) }
            if let v = ud.string(forKey: "\(v2Prefix).alignment") { ud.set(v, forKey: PanelState.K.alignment) }
            if let v = ud.object(forKey: "\(v2Prefix).isRTL")     { ud.set(v, forKey: PanelState.K.isRTL) }
            if let v = ud.object(forKey: "\(v2Prefix).focusMode") { ud.set(v, forKey: PanelState.K.focusMode) }
        }

        // 5. ALWAYS force clickThrough = false. Same anti-trap guarantee as
        //    Commit 1, preserved through takeover. Applies even on a fresh
        //    install with no source UUIDs.
        ud.set(false, forKey: PanelState.K.clickThrough)

        // 6. Mark takeover complete ONLY after everything above succeeded.
        ud.set(true, forKey: K.migrationV3TakeoverCompleted)
    }

    // MARK: Note CRUD (used by PanelController in Commit 2)

    /// Set the active note and persist `ft.activeNoteID`. Passing nil
    /// removes the key. Safe to call when the id isn't in `notes`.
    func setActiveNote(_ id: UUID?) {
        activeNoteID = id
        if let id = id {
            ud.set(id.uuidString, forKey: K.activeNoteID)
        } else {
            ud.removeObject(forKey: K.activeNoteID)
        }
    }

    /// Append a NoteState, persist `ft.notes`, and make it active.
    /// The caller is responsible for having seeded `ft.note.<id>.*` keys
    /// before calling — PanelController.newTab does this in the correct
    /// order (per-note keys first, then this call).
    func appendNote(_ note: NoteState) {
        notes.append(note)
        ud.set(notes.map { $0.id.uuidString }, forKey: K.notes)
        setActiveNote(note.id)
    }

    /// Permanently delete a note: drop from `notes[]`, rewrite `ft.notes`,
    /// purge `ft.note.<id>.*` keys. If the deleted note was active, pick
    /// the previous note (or first remaining) as the new active.
    /// Returns the new active id (nil if `notes` is now empty — caller
    /// should typically follow up with a fresh `appendNote`).
    @discardableResult
    func deleteNote(id: UUID) -> UUID? {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return activeNoteID }

        let wasActive = (activeNoteID == id)
        notes.remove(at: idx)
        ud.set(notes.map { $0.id.uuidString }, forKey: K.notes)

        let prefix = "ft.note.\(id.uuidString)"
        for suffix in [".text", ".createdAt", ".updatedAt"] {
            ud.removeObject(forKey: prefix + suffix)
        }

        if wasActive {
            if notes.isEmpty {
                setActiveNote(nil)
            } else {
                let pick = notes[max(0, idx - 1)].id
                setActiveNote(pick)
            }
        }
        return activeNoteID
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
        static let migrationV3TakeoverCompleted = "ft.migration.v3.takeoverCompleted"
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
