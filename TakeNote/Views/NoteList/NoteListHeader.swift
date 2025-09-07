//
//  NoteListHeader.swift
//  TakeNote
//
//  Created by Adam Drew on 9/7/25.
//

import SwiftUI

struct NoteListHeader: View {
    @Environment(TakeNoteVM.self) var takeNoteVM

    var folderSymbol: String {
        guard let container = takeNoteVM.selectedContainer else {
            return "folder"
        }
        if container.isTrash {
            return "trash"
        }
        if container.isTag {
            return "tag"
        }
        return "folder"
    }
    
    var noteCountLabel: String {
        let noNotes = "No notes"
        guard let container = takeNoteVM.selectedContainer else {
            return noNotes
        }
        if container.notes.isEmpty {
            return noNotes
        }
        if container.notes.count == 1 {
            return "\(String(describing: container.notes.count)) note"
        }
        return "\(String(describing: container.notes.count)) notes"
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {

                Label {
                    Text(
                        takeNoteVM.selectedContainer?.name
                            ?? "No folder selected",
                    )
                } icon: {
                    Image(systemName: folderSymbol)
                        .foregroundColor(.takeNotePink)
                }
                .font(.title)
                .fontWeight(.bold)

                Text(noteCountLabel)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        
    }
}
