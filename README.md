# FloatText

A lightweight floating text overlay for macOS. Designed as a conversational cue sheet — keep prompts, talking points, and reminders visible above other windows during live calls and recordings.

Native Swift + SwiftUI + AppKit. `NSTextView` under the hood for stable Hebrew / RTL editing.

## Status

MVP (v0.3). Local builds only — no signing, no notarization, no App Store. Runs on macOS 14 Sonoma or later. See [CHANGELOG.md](CHANGELOG.md) for what's new.

**v0.3 in one line:** a single floating panel with internal note **tabs** — replacing the earlier multiple-floating-windows model, which became cluttered with several translucent overlays on screen at once.

## Screenshot

![FloatText floating panel](docs/screenshot.png)

## What FloatText is

- A small translucent floating panel that stays above other apps
- A quick place to read from, copy from, and edit during a live conversation
- Multiple notes as tabs inside one panel
- Local-only — nothing leaves your machine

## What FloatText is not

- Not a note-taking database
- Not a document editor
- Not a markdown renderer
- Not synced — no iCloud, no accounts, no cloud
- Not (yet) a notarized public release

## Features

- **One floating panel with note tabs.** Switch between notes via a tab strip; each tab has its own text.
- **Per-note text color.** Each tab can have its own text color, shown as a color dot on the tab. The active tab is highlighted (filled background + border + bold label).
- Frameless floating panel that stays above other windows (Always on Top toggle)
- Editable multiline `NSTextView` with Hebrew / RTL support
- All smart-quote / auto-substitution / auto-correct disabled — keeps Hebrew punctuation stable
- Standard copy / paste / cut / undo (each tab has its own undo stack)
- Text alignment: left / center / right (panel-wide)
- RTL ↔ LTR toggle (panel-wide)
- Font size + / − (panel-wide)
- **Background strength** slider — controls the translucent backing layer from noticeably transparent to nearly solid; text always stays fully opaque
- Focus Mode — hides the bottom formatting bar; the tab header stays; text stays editable; hover to reveal the formatting bar
- Click-through Mode — clicks pass through to the apps beneath; exits via an on-screen **"Exit click-through"** control or the menu bar (see below)
- Menu bar icon with Show / Hide Panel, New Tab, Delete Note, Clear Note, plus mode toggles and Quit
- Hide Dock Icon toggle
- Launch at Login toggle
- Local persistence of every note's text + color, plus the panel's frame, font size, alignment, RTL state, opacity, and toggles
- First-launch seed text with a short Hebrew conversation structure

## Notes & tabs

FloatText distinguishes carefully between **non-destructive** and **destructive** actions. Nothing destructive happens without an explicit confirmation dialog.

### Action semantics

| Action | Destructive? | What happens to the panel | What happens to text / state | How to restore |
|---|---|---|---|---|
| **Hide Panel** | No | The whole panel disappears from screen | All notes & settings preserved | Show Panel |
| **Show Panel** | No | Reveals the panel; creates a blank note if somehow none exist | n/a | n/a |
| **New Tab** | No | A fresh blank note tab appears and becomes active | New empty note (inherits the active note's color) | n/a |
| **Switch Tab** | No | The editor shows the clicked note | unchanged | n/a |
| **Clear Note** | **Yes** (text only) | Tab stays; text is wiped | Only the active note's text is removed; its color and the panel settings are kept | Cannot — but the tab itself remains |
| **Delete Note** | **Yes** (note) | Tab is removed | The active note's text + color are permanently removed | Cannot — gone |

Delete Note and Clear Note **both require a confirmation dialog**. If you delete the last remaining note, a fresh blank note is created so the panel always has at least one tab.

### Top area — two rows

1. **Action header** (a toolbar strip): destructive **Delete Note** (🗑, red) on the left; safe **Hide Panel** (👁) and **Clear Note** (🧹) on the right. Both 🗑 and 🧹 confirm first.
2. **Tab strip**: the note tabs (each with a color dot), plus a trailing **+** to create a new tab.

The top area stays visible in Focus Mode and during Click-through, so you always know which note is active.

### Bottom controls bar (formatting / reading only)

- A− / A+ font size
- Text color picker (**applies to the active note only**)
- Alignment (left / center / right)
- RTL / LTR toggle
- Focus Mode toggle
- Background strength slider (range **0.35 … 1.0**)

### Click-through Mode

Click-through makes the panel pass mouse clicks to whatever app is behind it. Because `NSPanel.ignoresMouseEvents` is a window-level property, no control inside the main panel can be clicked while it's on — so FloatText shows a **separate, always-interactive "Exit click-through" control window** at the panel's top-right corner. Click it to turn click-through off and restore normal interaction. The menu bar item **Disable Click-through** does the same and is always available. There is no trap state.

### Menu bar

```
Show Panel / Hide Panel                ⌘⇧H
─────────
New Tab                                ⌘T
Delete Note…                           (confirmation)
Clear Note…                            (confirmation)
─────────
Focus Mode                             ⌘⇧F
Always on Top
Click-through Mode
Disable Click-through                  (appears when click-through is on)
─────────
RTL                                    ⌘⇧R
─────────
Hide Dock Icon
Launch at Login
─────────
Quit FloatText                         ⌘Q
```

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
./scripts/uninstall.sh --purge     # also delete UserDefaults (saved notes,
                                   # panel position, colors, font size, etc.)
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

- ⌘⇧H — Show / Hide Panel
- ⌘T  — New Tab
- ⌘⇧F — Toggle Focus Mode
- ⌘⇧R — Toggle RTL / LTR
- ⌘Q  — Quit
- Standard ⌘C / ⌘V / ⌘X / ⌘Z / ⌘A inside the text view

Delete Note and Clear Note are intentionally without shortcuts and require confirmation.

## Data & migration

FloatText has migrated its on-disk format twice, always **non-destructively** — older keys are read, never deleted, so previous versions still work against the same `UserDefaults` domain and your data is never lost:

- **v0.1 → v0.2** — single flat keys → per-window keys (`ft.window.<uuid>.*`)
- **v0.2 → v0.3** — each window becomes a **note tab** (`ft.note.<uuid>.*`), with the first window's visual settings becoming the panel-wide settings (`ft.panel.*`)

The old v0.2 keys (`ft.windows`, `ft.window.<uuid>.*`) are **kept on disk** as a rollback / data-safety record even though the v0.2 source code has been removed. `./scripts/uninstall.sh --purge` clears everything if you want a clean slate.

## Known limitations

- **Unsigned local builds only.** No code signing, no notarization, no sandbox. Distributing the built `.app` to another Mac will trigger a Gatekeeper warning.
- **Launch at Login** uses `SMAppService`, which expects the app to live at a stable install location. From an unsigned development build it may report `.notRegistered` even after enabling — install via `install.sh` first.
- **Click-through Mode** is being used in real work and may need further hardening; if clicks don't pass through on your macOS version, please open an issue. The on-screen "Exit click-through" control and the menu rescue both prevent a trap state.
- **One tabbed panel.** Multiple separate tabbed panels ("New Panel") is **not implemented yet** — it's deferred and may be reconsidered after a week of real use.
- **No global hotkey** for show/hide. The menu bar icon is the always-available entry point.
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
├── AppState.swift                 Global settings + panel + notes[] + non-destructive migration
├── PanelState.swift               Panel-wide @Published state (frame, font, alignment, RTL, opacity, …)
├── NoteState.swift                Per-note @Published state (text, color, timestamps)
├── PanelController.swift          Owns the floating panel, the exit-control window, and tab actions
├── FloatingPanel.swift            NSPanel subclass — activating, floating, borderless feel
├── ClickThroughExitWindow.swift   Separate always-interactive "Exit click-through" control window
├── OverlayView.swift              SwiftUI root: action header + tab strip + editor + bottom bar
├── TabBar.swift                   Horizontal tab strip (color dots, active styling)
├── ControlsBar.swift              Bottom formatting bar (font, color, align, RTL, focus, opacity)
├── RTLTextView.swift              NSViewRepresentable around NSTextView (RTL-stable)
├── MenuBarMenu.swift              MenuBarExtra contents
└── LaunchAtLogin.swift            SMAppService wrapper
```

See [docs/design-notes.md](docs/design-notes.md) for rationale on the panel choice, the NSTextView decision, and RTL handling.

## Roadmap

- Signed / notarized Developer ID build
- Optional **New Panel** — multiple separate tabbed panels (deferred; reconsider after a week of use)
- Per-tab font size / opacity (currently panel-wide)
- Click-through hardening across macOS versions
- Global hotkey for Show / Hide
- Optional read-only / teleprompter scroll mode

## License

No license file yet. Treat as all rights reserved until one is added.
