//
//  ContainerSpec.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//

import WidgetKit

/*
 I wrote the initial TimelineProvider, but had ChatGPT refactor it so we could have different
 providers for different NoteContainers. Everything was the same for every NoteContainer except
 how we select it from the list of NoteContainers. So, this allows us to re-use this code but
 change the selection logic per-container
*/
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
                    excerpt: "This is an example note",
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
            NoteRow(id: $0.uuid, title: $0.title, excerpt: $0.excerpt, url: $0.url)
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
