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

@MainActor
final class AppState: ObservableObject {
    // Editor content
    @Published var text: String { didSet { scheduleTextPersist() } }

    // Typography & color
    @Published var fontSize: CGFloat { didSet { ud.set(Double(fontSize), forKey: K.fontSize) } }
    @Published var textColorHex: String { didSet { ud.set(textColorHex, forKey: K.textColorHex) } }

    // Window appearance
    @Published var backgroundOpacity: Double { didSet { ud.set(backgroundOpacity, forKey: K.bgOpacity) } }

    // Text behavior
    @Published var alignment: TextAlignmentOption { didSet { ud.set(alignment.rawValue, forKey: K.alignment) } }
    @Published var isRTL: Bool { didSet { ud.set(isRTL, forKey: K.isRTL) } }

    // Window behavior
    @Published var alwaysOnTop: Bool { didSet { ud.set(alwaysOnTop, forKey: K.alwaysOnTop) } }
    @Published var clickThrough: Bool { didSet { ud.set(clickThrough, forKey: K.clickThrough) } }
    @Published var focusMode: Bool { didSet { ud.set(focusMode, forKey: K.focusMode) } }
    @Published var hideDockIcon: Bool { didSet { ud.set(hideDockIcon, forKey: K.hideDockIcon) } }
    @Published var launchAtLogin: Bool { didSet { ud.set(launchAtLogin, forKey: K.launchAtLogin) } }

    // Window frame
    @Published var windowFrame: NSRect { didSet { persistFrame() } }

    private let ud = UserDefaults.standard
    private var textPersistTask: Task<Void, Never>?

    init() {
        let d = UserDefaults.standard

        // Text — seed on first launch if missing
        if let stored = d.string(forKey: K.text) {
            self.text = stored
        } else {
            self.text = AppState.seedText
        }

        self.fontSize = CGFloat(d.object(forKey: K.fontSize) as? Double ?? 18.0)
        self.textColorHex = d.string(forKey: K.textColorHex) ?? "#F2F2F2"
        self.backgroundOpacity = d.object(forKey: K.bgOpacity) as? Double ?? 0.75
        self.alignment = TextAlignmentOption(rawValue: d.string(forKey: K.alignment) ?? "") ?? .right
        self.isRTL = d.object(forKey: K.isRTL) as? Bool ?? true
        self.alwaysOnTop = d.object(forKey: K.alwaysOnTop) as? Bool ?? true
        self.clickThrough = d.object(forKey: K.clickThrough) as? Bool ?? false
        self.focusMode = d.object(forKey: K.focusMode) as? Bool ?? false
        self.hideDockIcon = d.object(forKey: K.hideDockIcon) as? Bool ?? false
        self.launchAtLogin = d.object(forKey: K.launchAtLogin) as? Bool ?? false

        if let frameStr = d.string(forKey: K.windowFrame) {
            self.windowFrame = NSRectFromString(frameStr)
        } else {
            self.windowFrame = NSRect(x: 200, y: 200, width: 460, height: 520)
        }
    }

    var textColor: NSColor {
        NSColor(hex: textColorHex) ?? .white
    }

    private func scheduleTextPersist() {
        textPersistTask?.cancel()
        textPersistTask = Task { [text] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                UserDefaults.standard.set(text, forKey: K.text)
            }
        }
    }

    private func persistFrame() {
        ud.set(NSStringFromRect(windowFrame), forKey: K.windowFrame)
    }

    enum K {
        static let text = "ft.text"
        static let fontSize = "ft.fontSize"
        static let textColorHex = "ft.textColorHex"
        static let bgOpacity = "ft.bgOpacity"
        static let alignment = "ft.alignment"
        static let isRTL = "ft.isRTL"
        static let alwaysOnTop = "ft.alwaysOnTop"
        static let clickThrough = "ft.clickThrough"
        static let focusMode = "ft.focusMode"
        static let hideDockIcon = "ft.hideDockIcon"
        static let launchAtLogin = "ft.launchAtLogin"
        static let windowFrame = "ft.windowFrame"
    }

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
