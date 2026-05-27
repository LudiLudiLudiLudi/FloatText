# Changelog

All notable changes to FloatText are recorded here.

## Unreleased

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
