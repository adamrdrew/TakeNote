import SwiftData
import SwiftUI

struct BackLinks: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Environment(\.dismiss) private var dismiss

    @State private var linkManager: NoteLinkManager?
    @State private var backLinkedNotes: [Note] = []

    private var hasBacklinks: Bool { !backLinkedNotes.isEmpty }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Label("Backlinks", systemImage: "link")
                    .font(.headline)
                if hasBacklinks {
                    Text("\(backLinkedNotes.count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.secondary.opacity(0.2)))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider()

            if !hasBacklinks {
                // Empty state
                VStack(spacing: 6) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text("No backlinks found")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // List of backlinks
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(backLinkedNotes) { note in
                            BacklinkRow(note: note) {
                                if let url = URL(string: note.getURL()) {
                                    #if os(iOS)
                                    dismiss()
                                    #endif
                                    openURL(url)
                                }
                            }
                            #if os(macOS)
                                .contextMenu {
                                    Button("Copy Link") {
                                        if let url = URL(string: note.getURL())
                                        {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(
                                                url.absoluteString,
                                                forType: .string
                                            )
                                        }
                                    }
                                }
                            #endif
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        #if os(macOS)
            .frame(width: 280, height: 320)  // nice compact popover
        #else
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .presentationDetents([.medium, .large])  // optional, feels native
            .presentationDragIndicator(.visible)  // optional
        #endif
        .onAppear {
            linkManager = NoteLinkManager(modelContext: modelContext)
            refresh()
        }
        .onChange(of: takeNoteVM.openNote) { _, _ in
            refresh()
        }
    }

    private func refresh() {
        guard let open = takeNoteVM.openNote,
            let mgr = linkManager
        else {
            backLinkedNotes = []
            return
        }
        // Notes that link TO the open note
        backLinkedNotes = mgr.getNotesThatLinkTo(open)
        // Optional: stable sort by title for consistent UI
        backLinkedNotes.sort {
            $0.title.localizedCaseInsensitiveCompare($1.title)
                == .orderedAscending
        }
    }
}

// MARK: - Row

private struct BacklinkRow: View {
    let note: Note
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                Text(note.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                Image(systemName: "arrow.up.right")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(isHovering ? 0.12 : 0.0))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(Text("Open \(note.title)"))
    }
}
