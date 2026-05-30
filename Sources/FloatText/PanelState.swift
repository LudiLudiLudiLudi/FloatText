import SwiftUI
import AppKit

/// Panel-wide visual + behavior state shared across all tabs (per the
/// v0.3 spec: visual settings are panel-wide for MVP; per-tab visuals
/// are a future enhancement).
///
/// Created in Commit 1 as a dormant data model — the existing v0.2
/// multi-window UI does NOT consume it yet. Commit 2 will switch the
/// visible UI over.
///
/// Persistence: `ft.panel.*` keys. Defaults match WindowState's defaults
/// so the first-run feel is identical.
@MainActor
final class PanelState: ObservableObject {
    private let ud = UserDefaults.standard

    @Published var windowFrame: NSRect { didSet { ud.set(NSStringFromRect(windowFrame), forKey: K.frame) } }
    @Published var fontSize: CGFloat { didSet { ud.set(Double(fontSize), forKey: K.fontSize) } }
    @Published var textColorHex: String { didSet { ud.set(textColorHex, forKey: K.color) } }
    @Published var backgroundOpacity: Double { didSet { ud.set(backgroundOpacity, forKey: K.opacity) } }
    @Published var alignment: TextAlignmentOption { didSet { ud.set(alignment.rawValue, forKey: K.alignment) } }
    @Published var isRTL: Bool { didSet { ud.set(isRTL, forKey: K.isRTL) } }
    @Published var focusMode: Bool { didSet { ud.set(focusMode, forKey: K.focusMode) } }
    @Published var clickThrough: Bool { didSet { ud.set(clickThrough, forKey: K.clickThrough) } }

    var textColor: NSColor { NSColor(hex: textColorHex) ?? .white }

    init() {
        let d = UserDefaults.standard
        self.windowFrame = d.string(forKey: K.frame).map { NSRectFromString($0) }
            ?? NSRect(x: 200, y: 200, width: 460, height: 520)
        self.fontSize = CGFloat(d.object(forKey: K.fontSize) as? Double ?? 18.0)
        self.textColorHex = d.string(forKey: K.color) ?? "#F2F2F2"
        // Background strength. Clamp to a readable band: at low values the
        // tint nearly vanishes and text sits on whatever app is behind,
        // producing muddy contrast. Floor 0.65; default 0.75.
        let storedOpacity = d.object(forKey: K.opacity) as? Double ?? 0.75
        let clamped = max(0.65, min(0.98, storedOpacity))
        self.backgroundOpacity = clamped
        // Persist the clamp now (init assignment does not fire didSet), so a
        // previously-saved out-of-range value is normalized on disk too.
        if clamped != storedOpacity {
            d.set(clamped, forKey: K.opacity)
        }
        self.alignment = TextAlignmentOption(rawValue: d.string(forKey: K.alignment) ?? "") ?? .right
        self.isRTL = d.object(forKey: K.isRTL) as? Bool ?? true
        self.focusMode = d.object(forKey: K.focusMode) as? Bool ?? false
        self.clickThrough = d.object(forKey: K.clickThrough) as? Bool ?? false
    }

    enum K {
        static let frame = "ft.panel.frame"
        static let fontSize = "ft.panel.fontSize"
        static let color = "ft.panel.color"
        static let opacity = "ft.panel.opacity"
        static let alignment = "ft.panel.alignment"
        static let isRTL = "ft.panel.isRTL"
        static let focusMode = "ft.panel.focusMode"
        static let clickThrough = "ft.panel.clickThrough"
    }
}
