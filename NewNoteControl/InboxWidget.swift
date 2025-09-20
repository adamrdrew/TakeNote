//
//  InboxWidget.swift
//  TakeNote
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry Models
struct NoteRow: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: String
}

struct NoteListEntry: TimelineEntry {
    let date: Date
    let rows: [NoteRow]
    let isPlaceholder: Bool
    let name: String
    let symbol: String
    let color: UInt32
    let totalNoteCount: Int
}

protocol ContainerSpec {
    // Pick which container to show from your snapshot
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot?

    // Optional: fallbacks for placeholder/meta if snapshot is missing fields
    static var placeholderName: String { get }
    static var placeholderSymbol: String { get }
    static var placeholderColor: UInt32 { get }
}

extension ContainerSpec {
    static var placeholderName: String { "TakeNote" }
    static var placeholderSymbol: String { "text.pad" }
    static var placeholderColor: UInt32 { 0x000000 }
}

struct ContainerProvider<Spec: ContainerSpec>: TimelineProvider {
    func placeholder(in context: Context) -> NoteListEntry {
        NoteListEntry(
            date: .now,
            rows: [
                .init(
                    id: .init(),
                    title: "Example note",
                    url: "takenote://note/placeholder"
                )
            ],
            isPlaceholder: true,
            name: Spec.placeholderName,
            symbol: Spec.placeholderSymbol,
            color: Spec.placeholderColor,
            totalNoteCount: 0
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NoteListEntry) -> Void
    ) {
        completion(placeholder(in: context))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<NoteListEntry>) -> Void
    ) {
        guard let snapshot = SnapshotController.readSnapshot(),
            let container = Spec.select(from: snapshot)
        else {
            // If no snapshot yet, retry soon so it feels responsive
            let entry = placeholder(in: context)
            let next = Date().addingTimeInterval(45)
            completion(Timeline(entries: [entry], policy: .after(next)))
            return
        }

        let rows: [NoteRow] = container.notes.map {
            NoteRow(id: $0.uuid, title: $0.title, url: $0.url)
        }

        let entry = NoteListEntry(
            date: .now,
            rows: rows,
            isPlaceholder: false,
            name: container.name,
            symbol: container.symbol,
            color: container.color,
            totalNoteCount: container.totalNoteCount
        )

        let refreshIn: TimeInterval = rows.isEmpty ? 45 : 600
        completion(
            Timeline(
                entries: [entry],
                policy: .after(Date().addingTimeInterval(refreshIn))
            )
        )
    }
}

// Inbox
struct InboxSpec: ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot? {
        snapshot.containers.first(where: { $0.isInbox })
    }
    static let placeholderSymbol = "tray.full"
    static let placeholderName = "Inbox"
}

// Starred
struct StarredSpec: ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot? {
        snapshot.containers.first(where: { $0.isStarred })
    }
    static let placeholderSymbol = "star.fill"
    static let placeholderName = "Starred"
}

// MARK: - View
struct NoteEntryView: View {
    let entry: NoteListEntry
    let showNewButton: Bool

    var body: some View {
        VStack {
            // Title row + actions
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: entry.symbol)
                Text(entry.name)
                    .font(.headline).bold()
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(entry.totalNoteCount)")
                    .font(.headline).bold()
                    .foregroundStyle(.primary)
            }
            //.frame(maxHeight: .infinity, alignment: .top)

            // Note list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.rows.prefix(3)) { row in
                    if let url = URL(string: row.url) {
                        Link(destination: url) {
                            Text(row.title.isEmpty ? "Untitled" : row.title)
                                .font(.callout)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if !entry.isPlaceholder && entry.rows.isEmpty {
                    Text("No notes")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )

            HStack {
                Spacer()
                if showNewButton {
                    // Create a new note via your AppIntent
                    Button(intent: NewNoteIntent()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .imageScale(.medium)
                            .symbolRenderingMode(.hierarchical)
                            .accessibilityLabel("New Note")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(for: .widget) {
            // Your custom brand color (exists in your asset catalog)
            ZStack {
                Color(.takeNotePink)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.33)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
}

// MARK: - Widget
struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.adamdrew.takenote.inboxWidget",
            provider: ContainerProvider<InboxSpec>()
        ) { entry in
            NoteEntryView(entry: entry, showNewButton: true)
        }
        .configurationDisplayName("Inbox")
        .description("Shows your inbox")
        .supportedFamilies([.systemSmall /*, .systemMedium */])
    }
}

struct StarredWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.adamdrew.takenote.starredWidget",
            provider: ContainerProvider<StarredSpec>()
        ) { entry in
            NoteEntryView(entry: entry, showNewButton: false)
        }
        .configurationDisplayName("Starred")
        .description("Shows your starred notes")
        .supportedFamilies([.systemSmall /*, .systemMedium */])
    }
}
