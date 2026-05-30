import SwiftUI
import AppKit

/// One note (one tab in the future tabbed panel). Created in Commit 1 as a
/// dormant data model — the existing v0.2 multi-window UI does NOT consume
/// it yet. Commit 2 will switch the visible UI over.
///
/// Persistence: `ft.note.<uuid>.text` / `.createdAt` / `.updatedAt`.
/// Text writes are debounced 500 ms, matching WindowState.
@MainActor
final class NoteState: ObservableObject, Identifiable {
    let id: UUID
    private let prefix: String
    private let ud = UserDefaults.standard
    private var textPersistTask: Task<Void, Never>?

    @Published var text: String { didSet { scheduleTextPersist() } }
    let createdAt: Date
    @Published var updatedAt: Date {
        didSet { ud.set(updatedAt.timeIntervalSince1970, forKey: K.updatedAt(prefix)) }
    }

    /// Per-note text color (v0.3 follow-up). Each tab can have its own
    /// visual identity. Persisted as `ft.note.<uuid>.color`.
    @Published var textColorHex: String {
        didSet { ud.set(textColorHex, forKey: K.color(prefix)) }
    }

    var textColor: NSColor { NSColor(hex: textColorHex) ?? .white }

    /// Derived label for the tab strip. First non-empty line of the text,
    /// trimmed and capped at 24 chars; falls back to "Untitled" when empty.
    /// Derived on the fly — no separate title field to keep persistence
    /// minimal for MVP.
    var displayTitle: String {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.count > 24 {
                return String(line.prefix(24)) + "…"
            }
            return line
        }
        return "Untitled"
    }

    /// Construct in-memory with given values; caller is responsible for
    /// persisting if needed (used during migration / new tab).
    init(id: UUID, text: String, createdAt: Date, updatedAt: Date,
         textColorHex: String = "#F2F2F2") {
        self.id = id
        self.prefix = "ft.note.\(id.uuidString)"
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.textColorHex = textColorHex
    }

    /// Load from `ft.note.<id>.*` keys. Returns nil if no text key has ever
    /// been written — caller can decide whether to treat that as "deleted"
    /// or "needs seeding".
    init?(id: UUID) {
        let d = UserDefaults.standard
        let prefix = "ft.note.\(id.uuidString)"
        guard let storedText = d.string(forKey: "\(prefix).text") else { return nil }
        let created = (d.object(forKey: "\(prefix).createdAt") as? Double)
            .map { Date(timeIntervalSince1970: $0) } ?? Date()
        let updated = (d.object(forKey: "\(prefix).updatedAt") as? Double)
            .map { Date(timeIntervalSince1970: $0) } ?? created

        // Per-note color backfill (idempotent). Resolution order:
        //   1. ft.note.<id>.color           (already per-note — use it)
        //   2. ft.window.<id>.color         (the note reuses its v0.2 window
        //                                    UUID, so this recovers each
        //                                    note's ORIGINAL v0.2 color)
        //   3. ft.panel.color               (the migrated panel-wide color)
        //   4. #F2F2F2                       (safe default)
        // The resolved value is written back so subsequent launches are stable.
        let resolvedColor: String
        if let c = d.string(forKey: "\(prefix).color") {
            resolvedColor = c
        } else if let c = d.string(forKey: "ft.window.\(id.uuidString).color") {
            resolvedColor = c
        } else if let c = d.string(forKey: "ft.panel.color") {
            resolvedColor = c
        } else {
            resolvedColor = "#F2F2F2"
        }

        self.id = id
        self.prefix = prefix
        self.text = storedText
        self.createdAt = created
        self.updatedAt = updated
        self.textColorHex = resolvedColor
        // Persist the resolved color so the backfill only happens once.
        d.set(resolvedColor, forKey: "\(prefix).color")
    }

    private func scheduleTextPersist() {
        textPersistTask?.cancel()
        let textKey = K.text(prefix)
        let updatedKey = K.updatedAt(prefix)
        let now = Date().timeIntervalSince1970
        textPersistTask = Task { [text] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                UserDefaults.standard.set(text, forKey: textKey)
                UserDefaults.standard.set(now, forKey: updatedKey)
            }
        }
    }

    enum K {
        static func text(_ p: String) -> String      { "\(p).text" }
        static func createdAt(_ p: String) -> String { "\(p).createdAt" }
        static func updatedAt(_ p: String) -> String { "\(p).updatedAt" }
        static func color(_ p: String) -> String     { "\(p).color" }
    }
}
