# FloatText

A lightweight floating text overlay for macOS — a conversational cue sheet for live calls and recordings. Native Swift + SwiftUI, with AppKit for the window and `NSTextView` for stable Hebrew/RTL editing.

This is the MVP build: local dev only. No signing, no notarization, no App Store, no network, no analytics.

## Install (recommended)

Build a Release `.app` and copy it into `~/Applications`:

```bash
./scripts/install.sh
open ~/Applications/FloatText.app
```

To install for all users in `/Applications` instead (requires sudo):

```bash
./scripts/install.sh --system
```

The script:
1. Runs `xcodebuild` in Release configuration
2. Stops any running FloatText
3. Replaces any prior install at the target path
4. Registers the new `.app` with LaunchServices

Installs are idempotent — rerun `install.sh` after any code change.

## Uninstall

```bash
./scripts/uninstall.sh             # remove from ~/Applications, keep settings
./scripts/uninstall.sh --system    # remove from /Applications (sudo)
./scripts/uninstall.sh --purge     # also delete UserDefaults (saved text,
                                   # window position, font size, colors, etc.)
```

`--system` and `--purge` may be combined.

## Run from Xcode (development)

```bash
./scripts/open.sh    # opens FloatText.xcodeproj in Xcode
```

Then ⌘R in Xcode.

> If you have Cursor, AppCode, or another editor installed, it may have taken over as the default opener for `.xcodeproj` bundles. `open.sh` forces Xcode via `open -b com.apple.dt.Xcode` regardless of the default handler. If you'd rather open it manually, run: `open -a Xcode FloatText.xcodeproj`.

A `Package.swift` is also included for `swift build` / `swift run` (CLI binary only, not a `.app` bundle — useful for quick compile checks but the menu-bar app behavior needs the `.app` bundle, so use Xcode or `install.sh` for actual runs).

Requires Xcode 15+ on macOS 14 Sonoma or later.

## Features

- Frameless floating panel that stays above other windows (toggle: Always on Top)
- Editable multiline `NSTextView` with Hebrew/RTL support
- Smart-quote / auto-substitution / auto-correct all OFF (Hebrew punctuation stability)
- Standard copy / paste / cut / undo
- Text alignment: left / center / right
- RTL ↔ LTR toggle
- Font size +/-
- Text color picker
- Background opacity slider
- Focus Mode — hides the controls bar; text remains editable
- Click-through Mode — clicks pass through to apps beneath. **Reversible only from the menu bar.**
- Menu bar icon with Show/Hide, mode toggles, Quit
- Hide Dock Icon toggle (conditional — see "Known limits" below)
- Launch at Login toggle (conditional — see "Known limits" below)
- Local persistence via `UserDefaults`: text, frame, font size, color, opacity, alignment, RTL, toggles
- First-launch seed text with a short Hebrew conversation structure

## Keyboard shortcuts

- ⌘⇧H — Show / Hide
- ⌘⇧F — Toggle Focus Mode
- ⌘⇧R — Toggle RTL / LTR
- ⌘Q  — Quit
- Standard ⌘C / ⌘V / ⌘X / ⌘Z / ⌘A in the text view

## Step-3 focus gate (mandatory acceptance check)

Per the implementation plan, before relying on this build during a real recording, verify in the running app:

1. Hebrew typing
2. Mixed Hebrew/English paste
3. Mouse + ⇧+arrows selection
4. ⌘C / ⌘V / ⌘X / ⌘Z
5. Clicking the panel makes the text view focused
6. Focus returns after using the menu bar
7. Quotes are not auto-converted

If any item fails, the activating `NSPanel` choice in `FloatingPanel.swift` is wrong — fall back to a plain `NSWindow`.

## Known limits (MVP)

- **Local dev only.** No code signing, no notarization, no sandbox. Don't distribute this build to others.
- **Launch at Login** uses `SMAppService` which requires the app to be in a stable, signed install location. From an unsigned `swift run` / Xcode-debug build, the toggle may report `.notRegistered` even after enabling — this is expected. The UI reflects the true `SMAppService` state, not a cached value.
- **Hide Dock Icon** toggles `NSApp.setActivationPolicy(.accessory ↔ .regular)` at runtime. If it ever causes panel-focus regressions, revert it via the menu bar (it will toggle back to `.regular`).
- **No global hotkey** for show/hide. The menu bar item is the always-available entry point.
- **No multi-document.** One panel, one persisted text blob. Deliberate.

## Architecture

```
Sources/FloatText/
├── FloatTextApp.swift            @main + AppDelegate + MenuBarExtra
├── AppState.swift                @Published persisted state, seed text, color helpers
├── FloatingPanel.swift           NSPanel subclass — activating, floating, borderless feel
├── FloatingPanelController.swift Wires panel to SwiftUI host; observes state
├── OverlayView.swift             SwiftUI root: VisualEffect + tint + text + controls
├── ControlsBar.swift             A-/A+, color, opacity, alignment, RTL, Focus toggle
├── RTLTextView.swift             NSViewRepresentable around NSTextView (RTL-stable)
├── VisualEffectView.swift        NSVisualEffectView bridge
├── MenuBarMenu.swift             MenuBarExtra contents
└── LaunchAtLogin.swift           SMAppService wrapper
```

See [docs/design-notes.md](docs/design-notes.md) for rationale on the panel choice and RTL handling.

## Privacy

- Zero network traffic.
- No analytics, no telemetry, no accounts, no cloud.
- All persisted state lives in `UserDefaults` for the app's bundle id.

## Roadmap (post-MVP)

- Signed/notarized Developer ID build
- Global hotkey for Show/Hide
- Optional read-only / teleprompter scroll mode
- Multiple stored snippets
