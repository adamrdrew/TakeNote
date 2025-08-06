//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI

struct NoteListEntry: View {
    @Environment(\.modelContext) private var modelContext
    var note: Note

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "note.text")
                Text(note.title)
                    .font(.headline)

            }
            Text(note.createdDate, style: .date)
        }
        .padding(10)
        .contextMenu {
            Button(action: {
                modelContext.delete(note)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
