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
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.85))
                .help("New Tab")
            }
            .padding(.horizontal, 2)
        }
    }
}

/// One tab. Observes its NoteState so the displayTitle and color marker
/// stay live as the user edits the note.
private struct TabButton: View {
    @ObservedObject var note: NoteState
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 5) {
                // Color marker — this note's own text color, so tabs are
                // identifiable at a glance.
                Circle()
                    .fill(Color(nsColor: note.textColor))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.5)
                    )

                Text(note.displayTitle)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? Color.white.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.6))
    }
}
