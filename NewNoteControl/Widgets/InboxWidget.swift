//
//  InboxWidget.swift
//  TakeNote
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Entry Models




struct InboxSpec: ContainerSpec {
    static func select(from snapshot: Snapshot) -> NoteContainerSnapshot? {
        snapshot.containers.first(where: { $0.isInbox })
    }
    static let placeholderSymbol = "tray.full"
    static let placeholderName = "Inbox"
}


struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "com.adamdrew.takenote.inboxWidget",
            provider: ContainerProvider<InboxSpec>()
        ) { entry in
            NoteContainerWidgetView(entry: entry, showNewButton: true)
        }
        .configurationDisplayName("Inbox")
        .description("Recently updated notes from your TakeNote Inbox.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}


