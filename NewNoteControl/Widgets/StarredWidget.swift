//
//  StarredSpec.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//

import WidgetKit
import SwiftUI

struct StarredSpec: ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot? {
        snapshot.containers.first(where: { $0.isStarred })
    }
    static let placeholderSymbol = "star.fill"
    static let placeholderName = "Starred"
}

struct StarredWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.adamdrew.takenote.starredWidget",
            provider: ContainerProvider<StarredSpec>()
        ) { entry in
            NoteContainerWidgetView(entry: entry, showNewButton: false)
        }
        .configurationDisplayName("Starred")
        .description("Shows your starred notes")
        .supportedFamilies([.systemSmall /*, .systemMedium */])
    }
}
