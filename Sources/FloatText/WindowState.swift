import SwiftUI
import AppKit

/// Per-window state. One instance per FloatText panel. Persisted under
/// `ft.window.<id>.*` keys so multiple windows can coexist without colliding.
///
/// Commit 1 of the multi-window refactor: there is still only one of these
/// in practice (created from a legacy-key migration on first launch, or seeded
/// fresh). Future commits will allow multiple WindowStates to live in
/// AppState.windows simultaneously.
@MainActor
final class WindowState: ObservableObject, Identifiable {
    let id: UUID
    private let prefix: String
    private let ud = UserDefaults.standard
    private var textPersistTask: Task<Void, Never>?

    // MARK: Per-window properties

    @Published var text: String { didSet { scheduleTextPersist() } }
    @Published var fontSize: CGFloat { didSet { ud.set(Double(fontSize), forKey: K.fontSize(prefix)) } }
    @Published var textColorHex: String { didSet { ud.set(textColorHex, forKey: K.color(prefix)) } }
    @Published var backgroundOpacity: Double { didSet { ud.set(backgroundOpacity, forKey: K.opacity(prefix)) } }
    @Published var alignment: TextAlignmentOption { didSet { ud.set(alignment.rawValue, forKey: K.alignment(prefix)) } }
    @Published var isRTL: Bool { didSet { ud.set(isRTL, forKey: K.isRTL(prefix)) } }
    @Published var clickThrough: Bool { didSet { ud.set(clickThrough, forKey: K.clickThrough(prefix)) } }
    @Published var focusMode: Bool { didSet { ud.set(focusMode, forKey: K.focusMode(prefix)) } }
    @Published var windowFrame: NSRect { didSet { ud.set(NSStringFromRect(windowFrame), forKey: K.frame(prefix)) } }

    var textColor: NSColor { NSColor(hex: textColorHex) ?? .white }

    // MARK: Init

    /// Load from `ft.window.<id>.*`, falling back to seed defaults when keys
    /// are missing. Pass `useSeedText: true` to inject the Hebrew template
    /// when no text has ever been stored for this id.
    init(id: UUID, useSeedText: Bool = false) {
        self.id = id
        self.prefix = "ft.window.\(id.uuidString)"
        let d = UserDefaults.standard

        let storedText = d.string(forKey: K.text(prefix))
        self.text = storedText ?? (useSeedText ? Self.seedText : "")

        self.fontSize = CGFloat(d.object(forKey: K.fontSize(prefix)) as? Double ?? 18.0)
        self.textColorHex = d.string(forKey: K.color(prefix)) ?? "#F2F2F2"
        self.backgroundOpacity = d.object(forKey: K.opacity(prefix)) as? Double ?? 0.60
        self.alignment = TextAlignmentOption(rawValue: d.string(forKey: K.alignment(prefix)) ?? "") ?? .right
        self.isRTL = d.object(forKey: K.isRTL(prefix)) as? Bool ?? true
        self.clickThrough = d.object(forKey: K.clickThrough(prefix)) as? Bool ?? false
        self.focusMode = d.object(forKey: K.focusMode(prefix)) as? Bool ?? false

        if let frameStr = d.string(forKey: K.frame(prefix)) {
            self.windowFrame = NSRectFromString(frameStr)
        } else {
            self.windowFrame = Self.defaultFrame
        }

        // Persist seed text if we just injected it so the next launch reads
        // the same value rather than re-seeding.
        if storedText == nil, useSeedText {
            d.set(self.text, forKey: K.text(prefix))
        }
    }

    // MARK: Persistence helpers

    private func scheduleTextPersist() {
        textPersistTask?.cancel()
        let key = K.text(prefix)
        textPersistTask = Task { [text] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                UserDefaults.standard.set(text, forKey: key)
            }
        }
    }

    // MARK: Constants

    static let defaultFrame = NSRect(x: 200, y: 200, width: 460, height: 520)

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

    /// Key builders. All keys are namespaced `ft.window.<uuid>.<suffix>`.
    enum K {
        static func text(_ p: String) -> String       { "\(p).text" }
        static func fontSize(_ p: String) -> String   { "\(p).fontSize" }
        static func color(_ p: String) -> String      { "\(p).color" }
        static func opacity(_ p: String) -> String    { "\(p).opacity" }
        static func alignment(_ p: String) -> String  { "\(p).alignment" }
        static func isRTL(_ p: String) -> String      { "\(p).isRTL" }
        static func clickThrough(_ p: String) -> String { "\(p).clickThrough" }
        static func focusMode(_ p: String) -> String  { "\(p).focusMode" }
        static func frame(_ p: String) -> String      { "\(p).frame" }
    }
}
