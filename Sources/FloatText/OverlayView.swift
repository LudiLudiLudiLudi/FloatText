import SwiftUI
import AppKit

/// SwiftUI root for the single floating panel (Commit 2 of the tabbed-
/// panel migration). Layout, top to bottom:
///
///   1. Top header — window + tab management:
///        LEFT:   [trash] Delete current note  (red, NSAlert confirm)
///        CENTER: TabBar (horizontal scrolling tab strip + `+` to add)
///        RIGHT:  [eye.slash] Hide panel
///                [eraser.fill] Clear current note (NSAlert confirm)
///      Visible when !panel.clickThrough. Stays visible in Focus Mode so
///      window + tab management remain reachable.
///
///   2. NoteEditor — the active note's RTLTextView, fills remaining space.
///      Keyed by `.id(activeNoteID)` so SwiftUI tears down and rebuilds
///      the editor (and its NSTextView) when the user switches tabs —
///      each tab gets a fresh undo stack and clean Hebrew/RTL setup.
///
///   3. ControlsBar (formatting) — A-/A+, color, alignment, RTL, focus,
///      opacity. Bound to PanelState (panel-wide for MVP per the v0.3
///      spec). Visible when !clickThrough AND (!focusMode || hovering).
///
/// When clickThrough is on the entire panel ignores mouse events, so both
/// bars are hidden — that absence is the visible state indicator.
struct OverlayView: View {
    @ObservedObject var appState: AppState
    var onHide: () -> Void = {}
    var onNewTab: () -> Void = {}
    var onDeleteNote: () -> Void = {}
    var onClearNote: () -> Void = {}
    @State private var isHovering = false

    private var showFormatControls: Bool {
        if appState.panel.clickThrough { return false }
        if !appState.panel.focusMode { return true }
        return isHovering
    }

    private var showTopHeader: Bool { !appState.panel.clickThrough }

    private var activeNote: NoteState? {
        appState.notes.first { $0.id == appState.activeNoteID }
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(appState.panel.backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showTopHeader {
                    topHeader
                }

                Group {
                    if let note = activeNote {
                        NoteEditor(note: note, panel: appState.panel)
                            .id(note.id) // recreate RTLTextView per tab
                    } else {
                        // Empty state. Shouldn't normally happen — the
                        // AppDelegate seeds a blank note when notes is
                        // empty — but show a neutral filler so the panel
                        // never collapses.
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .padding(.top, showTopHeader ? 0 : 8)

                if showFormatControls {
                    ControlsBar(panel: appState.panel, activeNote: activeNote)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: showFormatControls)
        .animation(.easeInOut(duration: 0.15), value: showTopHeader)
    }

    /// Two visually distinct rows so navigation (tabs) and actions
    /// (delete / hide / clear) are never confused:
    ///   Row 1 — action header (toolbar look): destructive Delete on the
    ///           left, safe Hide + Clear on the right.
    ///   Row 2 — tab strip only, with a trailing + to add a tab.
    private var topHeader: some View {
        VStack(spacing: 0) {
            actionHeader
            Divider()
                .overlay(Color.white.opacity(0.12))
            tabRow
        }
    }

    /// Row 1: actions. Given a faint toolbar background + bottom divider so
    /// it reads as a control strip, not a row of tabs.
    private var actionHeader: some View {
        HStack(spacing: 0) {
            // LEFT: destructive Delete, red, isolated.
            Button(action: confirmDelete) {
                Image(systemName: "trash")
            }
            .help("Delete this note (text will be permanently removed)")
            .foregroundStyle(.red.opacity(0.9))
            .disabled(activeNote == nil)

            Spacer(minLength: 0)

            // RIGHT: safe panel/note actions.
            HStack(spacing: 12) {
                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                }
                .help("Hide the panel (text is preserved; reopen via Show Panel)")
                .foregroundStyle(.white.opacity(0.85))

                Button(action: confirmClear) {
                    Image(systemName: "eraser.fill")
                }
                .help("Clear the text of the current note (the note itself stays)")
                .foregroundStyle(.white.opacity(0.85))
                .disabled(activeNote == nil)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
    }

    /// Row 2: tabs only.
    private var tabRow: some View {
        TabBar(
            appState: appState,
            onSelectNote: { appState.setActiveNote($0) },
            onNewTab: onNewTab
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func confirmDelete() {
        let alert = NSAlert()
        alert.messageText = "Delete this note?"
        alert.informativeText = "The note's text will be permanently removed. Other notes are unaffected."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            onDeleteNote()
        }
    }

    private func confirmClear() {
        let alert = NSAlert()
        alert.messageText = "Clear this note?"
        alert.informativeText = "The text in this note will be removed. The note itself will remain."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Clear")
        if #available(macOS 11.0, *) {
            alert.buttons.last?.hasDestructiveAction = true
        }
        if alert.runModal() == .alertSecondButtonReturn {
            onClearNote()
        }
    }
}

/// One tab's editor. Separated as its own View so SwiftUI's `.id(noteID)`
/// modifier can tear it down on tab switch — that recreates the RTLTextView
/// (and its NSTextView) with a fresh undo stack and per-tab editing state.
/// RTLTextView.swift itself is unchanged.
private struct NoteEditor: View {
    @ObservedObject var note: NoteState
    @ObservedObject var panel: PanelState

    var body: some View {
        RTLTextView(
            text: $note.text,
            fontSize: panel.fontSize,
            textColor: note.textColor,      // per-note color (v0.3 follow-up)
            alignment: panel.alignment.nsTextAlignment,
            isRTL: panel.isRTL
        )
    }
}
