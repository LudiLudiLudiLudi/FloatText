# Changelog

All notable changes to FloatText are recorded here.

## v0.3 — Single tabbed panel

The multiple-floating-windows model became cluttered (several translucent overlays on screen at once). v0.3 replaces it with **one floating panel containing note tabs**.

### Added

- **Single floating panel with internal note tabs.** A tab strip switches between notes; each tab has its own text and its own undo stack. New tabs are created with **+** in the tab strip or **New Tab** (⌘T) in the menu.
- **Per-note text color.** Each note carries its own text color, shown as a **color dot** on its tab. The color picker in the bottom bar edits the *active* note only. New tabs inherit the active note's color.
- **Active-tab styling.** The active tab has a filled background, a border, and a bold label so it's always obvious which note is shown.
- **Two-row top area.** An action header (Delete Note 🗑 left; Hide Panel 👁 + Clear Note 🧹 right) is visually separated from the tab strip below, so destructive actions can't be mistaken for tabs.
- **Clear Note** — wipes only the active note's text (the tab stays); requires confirmation.
- **Delete Note** — permanently removes the active note (tab + its text/color); requires confirmation. Deleting the last note creates a fresh blank one.
- **Hide Panel** — hides the whole panel non-destructively; **Show Panel** brings it back (and creates a blank note if somehow none exist).
- **Click-through escape control.** Because `NSPanel.ignoresMouseEvents` is window-level (no in-panel button can be clicked while it's on), click-through now shows a **separate, always-interactive "Exit click-through" control window** at the panel's top-right. The menu **Disable Click-through** remains as a second rescue. No trap state.
- **Background strength** slider with a wider, readable range (**0.35 … 1.0**): noticeably transparent at the low end, nearly solid at the high end. Only the backing layer changes — text keeps full alpha.
- **Non-destructive v0.2 → v0.3 migration.** Each v0.2 window becomes a note tab (`ft.note.<uuid>.*`); the first window's visuals become the panel-wide settings (`ft.panel.*`). Runs once, gated on `ft.migration.v3.takeoverCompleted`, with a strict write order so a crash mid-flight retries safely. v0.2 keys are read, never deleted.

### Changed

- Visual settings split: **per-note** = text color; **panel-wide** = font size, alignment, RTL direction, background strength, focus mode, click-through.
- `AppState` now holds one `PanelState` + a `notes: [NoteState]` array + `activeNoteID` instead of a windows array.
- The editor is rebuilt per tab (SwiftUI `.id(activeNoteID)`), giving each tab a clean `NSTextView` and its own undo stack.
- Tab label font size increased (11 → 13 pt) for readability; color dot 7 → 8 pt.
- Click-through no longer restructures the panel — the tab header stays visible with a small "click-through" status badge.

### Fixed

- **Background-strength slider was inert.** Root cause: `OverlayView` observed `appState` but read `appState.panel.backgroundOpacity`; as a nested `ObservableObject`, `PanelState`'s changes didn't re-render the view. Now `OverlayView` observes `PanelState` directly.
- **Click-through stuck-panel bug.** Root cause: the Combine subscriber re-read `appState.panel.clickThrough`, but `@Published` fires in `willSet` (before the value commits) — so every toggle applied the *inverted* state, leaving the panel ignoring all mouse events after being turned off. Fixed by using the value the publisher delivers; the OFF path now fully restores interactivity (`makeKey`, `activate`, first responder, movable-by-background).

### Removed (source only — data preserved)

- Deleted the dormant v0.2 source: `WindowState.swift`, `WindowManager.swift`, `FloatingPanelController.swift`, and the `AppState.windows[]` plumbing + redundant snapshot migration.
- **On-disk v0.2 data is intentionally preserved** (`ft.windows`, `ft.window.<uuid>.*`) as a rollback / data-safety record. `./scripts/uninstall.sh --purge` clears everything.

### Not yet implemented

- **New Panel** — multiple separate tabbed panels. Deferred; will be reconsidered after about a week of real use.
- Per-tab font size / opacity (currently panel-wide).

## v0.2 — Multiple windows (superseded by v0.3)

### Added

- **Multiple windows.** Open several floating panels at once; each panel has its own text, frame, font size, color, opacity, alignment, RTL state, focus mode, and click-through state.
- **`WindowManager`** orchestrating the per-window `FloatingPanelController`s and tracking the active (most recently focused) window for menu bar commands.
- **Menu bar actions for multi-window:**
  - `Show All Windows` (⌘⇧H) — reveals every hidden panel; creates one new blank panel when no windows exist (so the menu never reaches a dead end).
  - `Hide All Windows` — `orderOut` on every visible panel; disabled when none are visible.
  - `New Window` (⌘N) — creates a fresh blank panel.
  - `Hide Current Window` (⌘W) — hides only the active panel, non-destructively.
  - `Delete Current Window…` — permanently removes the active panel and purges its persisted state (NSAlert confirmation required).
  - `Clear Current Note…` — wipes only the active panel's text, keeps the window (NSAlert confirmation required).
  - `Disable Click-through (All Windows)` — appears only when at least one window is in click-through mode; guarantees a no-trap-state exit in multi-window setups.
- **In-window top header** with a left/right split that visually isolates the destructive action:
  - Left: 🗑 `trash` (red) — Delete this window, with confirmation.
  - Right: ➕ `plus` (New Window), 👁 `eye.slash` (Hide), 🧹 `eraser.fill` (Clear Note, with confirmation).
- **Non-destructive Hide** behavior — text, frame, color, opacity, alignment, RTL state all preserved; restorable via `Show All Windows`.
- **Destructive Delete** behavior — purges `ft.window.<uuid>.*` UserDefaults keys and removes the UUID from `ft.windows`; confirmation required.
- **One-shot, non-destructive migration** from the v0.1 flat-key UserDefaults schema (`ft.text`, `ft.fontSize`, etc.) to the v0.2 per-window schema (`ft.window.<uuid>.<key>`). Legacy keys are left in place so an older FloatText binary still works against the same defaults domain. Tracked by `ft.migration.v2.completed`.

### Changed

- Window-management controls moved **out of the bottom formatting bar** and into the top overlay header. The bottom bar is now formatting only.
- "Close" language replaced with clearer **Hide** / **Delete** / **Clear Note** semantics. `Close Window` no longer exists; it was ambiguous (it removed the window from the active list but kept the per-window keys orphaned). The replacement actions are explicit about whether they are destructive and what they affect.
- `Show / Hide FloatText` (a single dynamic toggle) replaced with two explicit menu items: `Show All Windows` and `Hide All Windows`. With multiple panels in play, an explicit pair is clearer than a polymorphic toggle.
- Per-window state extracted from `AppState` into a new `WindowState` type. `AppState` now holds only global settings (`alwaysOnTop`, `hideDockIcon`, `launchAtLogin`) and the windows array.
- `FloatingPanelController` now takes `(appState, windowState, manager)` instead of just `state`.

### Fixed

- **Empty-state Show All Windows.** When all panels were closed and zero controllers existed, the prior single dynamic Show/Hide toggle did nothing on click. `Show All Windows` now creates one new blank window in that case so the menu bar never dead-ends.
- **Click-through focus restoration.** On the click-through OFF transition, `applyClickThrough` now explicitly calls `panel.makeKeyAndOrderFront(nil)` and walks the host view tree to set the `NSTextView` as first responder. The cursor is live immediately — previously the panel "looked normal" after disable but keystrokes went nowhere until the user manually clicked.
- **No more trap state for click-through in multi-window setups.** Added the `Disable Click-through (All Windows)` rescue menu item that appears whenever any window is in click-through mode.
- Window controls remain accessible in Focus Mode — the top header stays visible when the bottom formatting bar hides.

### Known issues

- **Click-through Mode is still being tested and may need further hardening.** The AppKit API in use (`panel.ignoresMouseEvents`) is correct and the rescue path prevents trap states, but real-world pass-through reliability has not been fully verified across macOS versions. If you find a case where clicks don't reach the app beneath FloatText, please open an issue with the host macOS version and the app you were trying to click through to.

## v0.1 — Initial MVP

- Single floating translucent panel, `NSTextView`-backed editor.
- Hebrew / RTL support with smart-quote and auto-substitution disabled.
- Per-window controls (font, color, alignment, RTL, focus mode, opacity).
- Menu bar Show/Hide, Always on Top, Click-through Mode (single window), Hide Dock Icon, Launch at Login, Quit.
- Local persistence in `UserDefaults`.
- Local-only install script (`./scripts/install.sh` → `~/Applications/FloatText.app`).
