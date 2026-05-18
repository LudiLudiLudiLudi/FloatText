import SwiftUI
import AppKit

struct RTLTextView: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: NSColor
    let alignment: NSTextAlignment
    let isRTL: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let big = CGFloat.greatestFiniteMagnitude
        let textView = PaddedTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: big, height: big)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [NSView.AutoresizingMask.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: big)
        textView.textContainer?.widthTracksTextView = true

        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.insertionPointColor = .white

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.string = text
        applyAttributes(to: textView)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let safe = NSRange(location: min(selected.location, (text as NSString).length), length: 0)
            textView.setSelectedRange(safe)
        }
        applyAttributes(to: textView)
    }

    private func applyAttributes(to textView: NSTextView) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        style.lineSpacing = 4

        let font = NSFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: style,
        ]

        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        if let storage = textView.textStorage, full.length > 0 {
            storage.setAttributes(attrs, range: full)
        }
        textView.typingAttributes = attrs
        textView.font = font
        textView.textColor = textColor
        textView.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
        textView.alignment = alignment
        textView.defaultParagraphStyle = style
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RTLTextView
        weak var textView: NSTextView?

        init(_ parent: RTLTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

private final class PaddedTextView: NSTextView {
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        self.textContainerInset = NSSize(width: 8, height: 12)
    }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.textContainerInset = NSSize(width: 8, height: 12)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.textContainerInset = NSSize(width: 8, height: 12)
    }
    override var acceptsFirstResponder: Bool { true }
}
