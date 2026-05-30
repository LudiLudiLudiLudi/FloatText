import SwiftUI

/// Horizontal tab strip. Listed in `notes` order; the active tab is
/// visually filled. A trailing `+` button creates a new tab.
///
/// Designed to live between fixed-width icon buttons in OverlayView's top
/// header, so it wraps its own ScrollView and takes flexible width.
struct TabBar: View {
    @ObservedObject var appState: AppState
    var onSelectNote: (UUID) -> Void
    var onNewTab: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(appState.notes) { note in
                    TabButton(
                        note: note,
                        isActive: note.id == appState.activeNoteID,
                        onSelect: { onSelectNote(note.id) }
                    )
                }
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.85))
                .help("New Tab")
            }
            .padding(.horizontal, 2)
        }
    }
}

/// One tab. Observes its NoteState so the displayTitle stays live as the
/// user types in the note's text.
private struct TabButton: View {
    @ObservedObject var note: NoteState
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(note.displayTitle)
                .font(.system(size: 11))
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(isActive ? Color.white.opacity(0.18) : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.65))
    }
}
