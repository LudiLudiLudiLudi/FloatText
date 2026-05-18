# FloatText design notes

## Why `NSPanel`, not `NSWindow`

A panel can be a key window without becoming the main window, which fits a floating overlay well. The plan originally considered `.nonactivatingPanel` to avoid stealing focus from the recording app — but editing is the primary workflow here, and a non-activating panel makes `NSTextView` focus unreliable (the text view may not become first responder on click, and shortcuts may route to the previous app). MVP therefore uses an **activating** panel. If we later add a "teleprompter" read-only mode, that mode can opt into `.nonactivatingPanel` separately.

## Why `NSTextView`, not SwiftUI `TextEditor`

SwiftUI's `TextEditor` is a wrapper around `NSTextView` but exposes very little of its behavior. For Hebrew + mixed-direction text we need direct control over:

- `baseWritingDirection` (per-paragraph and per-view)
- `NSMutableParagraphStyle.baseWritingDirection` in `typingAttributes`
- All the `isAutomatic…` toggles (smart quotes, dash substitution, text replacement, spelling correction, link/data detection, smart insert/delete) — Hebrew punctuation gets mangled by every one of these
- Transparent background (`drawsBackground = false`) so the overlay's translucency comes through

Going through the `NSViewRepresentable` route gives us all of that with no fight against SwiftUI's defaults.

## Why click-through must be menu-bar-reversible

Click-through sets `ignoresMouseEvents = true` on the panel. In that state the in-window controls bar receives no events, so a user who enables click-through and then loses the menu bar icon would be trapped. Mitigations:

1. The menu bar icon's "Click-through Mode" toggle is always reachable (the menu bar lives outside the panel).
2. ⌘Q from anywhere still quits the app, returning to a clean relaunch (state persists; the toggle defaults to OFF on relaunch only if the user explicitly relaunches after force-quit; otherwise the persisted value is loaded).

We do **not** add a global hotkey for this in MVP; the menu bar is the trusted rescue path.

## RTL toggle semantics

Independent of alignment:

- `isRTL = true, alignment = .right` — typical Hebrew block
- `isRTL = true, alignment = .center` — centered Hebrew header
- `isRTL = false, alignment = .left` — typical English block

Toggling RTL updates both the typing attributes (so newly inserted runs flow correctly) and the full-range attributes (so existing paragraphs visually rewrap).

## Persistence

`UserDefaults.standard` only. Text is debounced 500 ms; everything else writes immediately on change. The window frame is captured via `NSWindowDelegate.windowDidMove` / `windowDidResize`. There is no separate database, no JSON file, no iCloud.

## What we deliberately did NOT build for MVP

- No rich text (bold/italic/styled runs). Plain `string` only. The color and font size are uniform across the document.
- No markdown rendering.
- No multi-document or tabs.
- No global hotkey.
- No teleprompter auto-scroll.
- No sandboxing or signing.

These are post-MVP. The success criterion is one stable overlay during a real recording.
