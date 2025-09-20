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
                .init(id: .init(), title: "Grocery list", excerpt: "Eggs, spinach, oat milk, ground coffee, salmon fillet…", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Meeting with Sarah", excerpt: "Discuss Q4 roadmap, confirm budget allocations, and set deadlines for design review.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Book to read", excerpt: "Started ‘The Unknown River’—bookmark key quotes and impressions for later.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Workout plan", excerpt: "Push/pull/legs split — focus on progressive overload and consistent cardio.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Weekend trip ideas", excerpt: "Asheville hike, brewery tour, Airbnb cabin stay near downtown", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Code snippet", excerpt: "Refactor the data fetch into async/await, wrap in Task, handle errors cleanly.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Birthday gift ideas", excerpt: "Jane: vinyl player stand. Bob: new drill set. Don: concert tickets.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Recipe: Chicken curry", excerpt: "Marinate chicken in yogurt + spices, simmer with coconut milk, ginger, garlic.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Dream journal", excerpt: "Strange train ride, glowing sky, felt calm but uncertain—write more details later.", url: "takenote://note/placeholder"),
                .init(id: .init(), title: "Movies to watch", excerpt: "Hereditary, Past Lives, and the new Dune sequel when it comes out.", url: "takenote://note/placeholder")
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
