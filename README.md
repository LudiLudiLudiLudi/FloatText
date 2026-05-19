# FloatText

A lightweight floating text overlay for macOS. Designed as a conversational cue sheet — keep prompts, talking points, and reminders visible above other windows during live calls and recordings.

Native Swift + SwiftUI + AppKit. `NSTextView` under the hood for stable Hebrew / RTL editing.

## Status

MVP. Local builds only — no signing, no notarization, no App Store. Runs on macOS 14 Sonoma or later.

## Screenshot

![FloatText floating panel](docs/screenshot.png)

## What FloatText is

- A small translucent floating panel that stays above other apps
- A quick place to read from, copy from, and edit during a live conversation
- Local-only — nothing leaves your machine

## What FloatText is not

- Not a note-taking app
- Not a document editor
- Not a markdown renderer
- Not synced — no iCloud, no accounts, no cloud
- Not (yet) a notarized public release

## Features

- Frameless floating panel that stays above other windows (Always on Top toggle)
- Editable multiline `NSTextView` with Hebrew / RTL support
- All smart-quote / auto-substitution / auto-correct disabled — keeps Hebrew punctuation stable
- Standard copy / paste / cut / undo
- Text alignment: left / center / right
- RTL ↔ LTR toggle
- Font size + / −
- Text color picker
- Background opacity slider — real transparency, see through to the windows beneath
- Focus Mode — hides the controls bar; text stays editable; hover the panel to reveal controls
- Click-through Mode — clicks pass through to apps beneath (reversible from the menu bar icon)
- Menu bar icon with Show/Hide, mode toggles, and Quit
- Hide Dock Icon toggle
- Launch at Login toggle
- Local persistence of text, window frame, font size, color, opacity, alignment, RTL state, and toggles
- First-launch seed text with a short Hebrew conversation structure

## Install

```bash
git clone https://github.com/<your-user>/FloatText.git
cd FloatText
./scripts/install.sh
open ~/Applications/FloatText.app
```

To install for all users in `/Applications` (sudo):

```bash
./scripts/install.sh --system
```

The script builds in Release, stops any running FloatText, replaces an existing install if present, and registers the new `.app` with LaunchServices. Re-run after any code change — installs are idempotent.

## Uninstall

```bash
./scripts/uninstall.sh             # remove from ~/Applications, keep settings
./scripts/uninstall.sh --system    # remove from /Applications (sudo)
./scripts/uninstall.sh --purge     # also delete UserDefaults (saved text,
                                   # window position, colors, font size, etc.)
```

`--system` and `--purge` may be combined.

## Build from source

Requires Xcode 15+ on macOS 14 or later.

```bash
./scripts/open.sh    # opens FloatText.xcodeproj in Xcode
```

Then ⌘R.

> If Cursor, AppCode, or another editor has registered itself as the default opener for `.xcodeproj`, `open.sh` forces Xcode via `open -b com.apple.dt.Xcode`. To do it manually: `open -a Xcode FloatText.xcodeproj`.

A `Package.swift` is included for `swift build` / `swift run`, but those produce a bare CLI binary rather than a `.app` bundle — for the menu bar and floating panel behavior to work, use Xcode or `install.sh`.

## Keyboard shortcuts

- ⌘⇧H — Show / Hide
- ⌘⇧F — Toggle Focus Mode
- ⌘⇧R — Toggle RTL / LTR
- ⌘Q  — Quit
- Standard ⌘C / ⌘V / ⌘X / ⌘Z / ⌘A inside the text view

## Known limitations

- **Unsigned local builds only.** No code signing, no notarization, no sandbox. Distributing the built `.app` to another Mac will trigger a Gatekeeper warning.
- **Launch at Login** uses `SMAppService`, which expects the app to live at a stable install location. From an unsigned development build it may report `.notRegistered` even after enabling — install via `install.sh` first.
- **No global hotkey** for show/hide. The menu bar icon is the always-available entry point.
- **One panel, one persisted text blob.** No multi-document / tabs.
- **Narrow panels + large text** can wrap awkwardly. Either widen the panel or reduce font size to taste.

## Privacy

- Zero network traffic
- No analytics, no telemetry
- No accounts, no cloud, no sync
- All persisted state lives in `UserDefaults` under `com.floattext.FloatText`

## Architecture

```
Sources/FloatText/
├── FloatTextApp.swift             @main + AppDelegate + MenuBarExtra
├── AppState.swift                 @Published persisted state, seed text, color helpers
├── FloatingPanel.swift            NSPanel subclass — activating, floating, borderless feel
├── FloatingPanelController.swift  Wires panel to SwiftUI host; observes state
├── OverlayView.swift              SwiftUI root: tint + text + controls
├── ControlsBar.swift              A-/A+, color, opacity, alignment, RTL, Focus toggle
├── RTLTextView.swift              NSViewRepresentable around NSTextView (RTL-stable)
├── MenuBarMenu.swift              MenuBarExtra contents
└── LaunchAtLogin.swift            SMAppService wrapper
```

See [docs/design-notes.md](docs/design-notes.md) for rationale on the panel choice, the NSTextView decision, and RTL handling.

## Roadmap

- Signed / notarized Developer ID build
- Global hotkey for Show / Hide
- Optional read-only / teleprompter scroll mode
- Multiple stored snippets

## License

No license file yet. Treat as all rights reserved until one is added.
