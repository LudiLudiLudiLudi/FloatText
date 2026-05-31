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

/// App-level state for the v0.3 single tabbed panel.
///
/// Holds global settings (alwaysOnTop, hideDockIcon, launchAtLogin), the
/// panel-wide visual state (`panel`), and the list of note tabs (`notes` +
/// `activeNoteID`). Per-note state lives in `NoteState`; panel-wide visual
/// state in `PanelState`.
///
/// Migration chain on launch (all non-destructive — older keys are read,
/// never deleted, so prior FloatText versions still work against the same
/// UserDefaults domain):
///   1. migrateLegacyKeysIfNeeded()   v0.1 flat keys → v0.2 `ft.window.<uuid>.*`
///   2. performV3TakeoverIfNeeded()   v0.2 windows → v0.3 `ft.note.<uuid>.*` tabs
///   3. loadV3State()                 build the in-memory model from v0.3 keys
@MainActor
final class AppState: ObservableObject {
    // MARK: Global properties
    @Published var alwaysOnTop: Bool { didSet { ud.set(alwaysOnTop, forKey: K.alwaysOnTop) } }
    @Published var hideDockIcon: Bool { didSet { ud.set(hideDockIcon, forKey: K.hideDockIcon) } }
    @Published var launchAtLogin: Bool { didSet { ud.set(launchAtLogin, forKey: K.launchAtLogin) } }

    // MARK: Panel + notes
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
        // Placeholder; re-instantiated by loadV3State() after migration writes
        // ft.panel.* keys.
        self.panel = PanelState()

        migrateLegacyKeysIfNeeded()      // v0.1 flat keys → v0.2 ft.window.<uuid>.*
        performV3TakeoverIfNeeded()      // v0.2 → v0.3 tabs (sole v3 path)
        loadV3State()                    // build panel / notes / activeNoteID
    }

    // MARK: v0.1 → v0.2 migration (non-destructive)

    /// One-time, non-destructive migration from the v0.1 flat-key schema
    /// (`ft.text`, `ft.fontSize`, …) to the v0.2 per-window schema
    /// (`ft.window.<uuid>.*`). Pure UserDefaults manipulation. Legacy keys are
    /// NOT deleted. The v0.3 takeover then reads the resulting `ft.window.*`
    /// keys.
    private func migrateLegacyKeysIfNeeded() {
        if ud.bool(forKey: K.migrationV2Completed) { return }

        let legacy = LegacyKeys.self
        let hasLegacy = ud.object(forKey: legacy.text) != nil
            || ud.object(forKey: legacy.fontSize) != nil
            || ud.object(forKey: legacy.windowFrame) != nil

        if hasLegacy {
            let id = UUID()
            let prefix = "ft.window.\(id.uuidString)"

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

    // MARK: v0.2 → v0.3 takeover (non-destructive)

    /// Build the v0.3 tab model from the v0.2 `ft.windows` / `ft.window.<uuid>.*`
    /// keys: each window becomes a note tab. Reads UserDefaults directly — does
    /// not need the old in-memory WindowState. Gated on
    /// `ft.migration.v3.takeoverCompleted` so it runs at most once.
    ///
    /// Strict write order so a crash mid-flight never leaves `ft.notes` pointing
    /// at note keys that don't exist yet:
    ///   1. per-note keys (text + createdAt + updatedAt) for every window
    ///   2. ft.notes        (UUID array, preserves window order)
    ///   3. ft.activeNoteID (kept if still valid, else first)
    ///   4. ft.panel.*      (from the first window's visuals)
    ///   5. ft.panel.clickThrough = false (anti-trap)
    ///   6. ft.migration.v3.takeoverCompleted = true
    ///
    /// v0.2 keys (`ft.windows`, `ft.window.<uuid>.*`) are READ, never modified
    /// or deleted — they remain as a rollback / data-safety record.
    private func performV3TakeoverIfNeeded() {
        if ud.bool(forKey: K.migrationV3TakeoverCompleted) { return }

        let sourceUUIDs = (ud.array(forKey: K.windows) as? [String] ?? [])
            .compactMap { UUID(uuidString: $0) }

        if !sourceUUIDs.isEmpty {
            let nowEpoch = Date().timeIntervalSince1970

            // 1. Per-note keys from the latest v0.2 text.
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

            // 2. ft.notes preserves window order.
            ud.set(sourceUUIDs.map { $0.uuidString }, forKey: K.notes)

            // 3. ft.activeNoteID: keep if still valid, else first.
            let currentActive = ud.string(forKey: K.activeNoteID).flatMap { UUID(uuidString: $0) }
            if let active = currentActive, sourceUUIDs.contains(active) {
                // unchanged
            } else {
                ud.set(sourceUUIDs[0].uuidString, forKey: K.activeNoteID)
            }

            // 4. ft.panel.* from the first window's visuals.
            let firstID = sourceUUIDs[0]
            let v2Prefix = "ft.window.\(firstID.uuidString)"
            if let v = ud.string(forKey: "\(v2Prefix).frame")     { ud.set(v, forKey: PanelState.K.frame) }
            if let v = ud.object(forKey: "\(v2Prefix).fontSize")  { ud.set(v, forKey: PanelState.K.fontSize) }
            if let v = ud.string(forKey: "\(v2Prefix).color")     { ud.set(v, forKey: PanelState.K.color) }
            if let v = ud.object(forKey: "\(v2Prefix).opacity")   { ud.set(v, forKey: PanelState.K.opacity) }
            if let v = ud.string(forKey: "\(v2Prefix).alignment") { ud.set(v, forKey: PanelState.K.alignment) }
            if let v = ud.object(forKey: "\(v2Prefix).isRTL")     { ud.set(v, forKey: PanelState.K.isRTL) }
            if let v = ud.object(forKey: "\(v2Prefix).focusMode") { ud.set(v, forKey: PanelState.K.focusMode) }
        } else if ud.array(forKey: K.notes) == nil {
            // Fresh install (no v0.2 windows AND no v0.3 notes yet): seed one
            // note with the Hebrew conversation template so first-run feel is
            // unchanged from earlier versions.
            let id = UUID()
            let nowEpoch = Date().timeIntervalSince1970
            let prefix = "ft.note.\(id.uuidString)"
            ud.set(Self.seedText, forKey: "\(prefix).text")
            ud.set(nowEpoch, forKey: "\(prefix).createdAt")
            ud.set(nowEpoch, forKey: "\(prefix).updatedAt")
            ud.set([id.uuidString], forKey: K.notes)
            ud.set(id.uuidString, forKey: K.activeNoteID)
        }

        // 5. Anti-trap: never start in click-through.
        ud.set(false, forKey: PanelState.K.clickThrough)

        // 6. Mark complete only after everything above succeeded.
        ud.set(true, forKey: K.migrationV3TakeoverCompleted)
    }

    // MARK: Note CRUD (used by PanelController)

    /// Set the active note and persist `ft.activeNoteID`. Passing nil removes
    /// the key. Safe to call when the id isn't in `notes`.
    func setActiveNote(_ id: UUID?) {
        activeNoteID = id
        if let id = id {
            ud.set(id.uuidString, forKey: K.activeNoteID)
        } else {
            ud.removeObject(forKey: K.activeNoteID)
        }
    }

    /// Append a NoteState, persist `ft.notes`, and make it active. The caller
    /// seeds `ft.note.<id>.*` keys first (PanelController.newTab does this).
    func appendNote(_ note: NoteState) {
        notes.append(note)
        ud.set(notes.map { $0.id.uuidString }, forKey: K.notes)
        setActiveNote(note.id)
    }

    /// Permanently delete a note: drop from `notes[]`, rewrite `ft.notes`,
    /// purge `ft.note.<id>.*` keys. If the deleted note was active, pick the
    /// previous note (or first remaining) as the new active. Returns the new
    /// active id (nil if `notes` is now empty — caller should follow up with a
    /// fresh `appendNote`).
    @discardableResult
    func deleteNote(id: UUID) -> UUID? {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return activeNoteID }

        let wasActive = (activeNoteID == id)
        notes.remove(at: idx)
        ud.set(notes.map { $0.id.uuidString }, forKey: K.notes)

        let prefix = "ft.note.\(id.uuidString)"
        for suffix in [".text", ".createdAt", ".updatedAt", ".color"] {
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

    /// Build the in-memory model from the v0.3 UserDefaults keys.
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
        static let windows = "ft.windows"                       // v0.2, read-only now
        static let migrationV2Completed = "ft.migration.v2.completed"
        static let notes = "ft.notes"
        static let activeNoteID = "ft.activeNoteID"
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

    /// First-run seed for a brand-new install (no prior FloatText data).
    static let seedText = """
    פתיחה
    • שלום, תודה שהצטרפת. נדבר היום על …

    נקודות עיקריות
    • …
    • …
    • …

    שאלות המשך
    • …
    • …

    תזכורת לסיום
    • לסכם את ההסכמות
    • לסגור על צעד הבא
    """
}

// MARK: - NSColor hex helpers

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
