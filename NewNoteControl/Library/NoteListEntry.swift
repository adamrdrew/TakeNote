//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 9/20/25.
//

import SwiftUI
import WidgetKit


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
