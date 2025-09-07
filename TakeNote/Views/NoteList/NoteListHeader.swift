//
//  NoteListHeader.swift
//  TakeNote
//
//  Created by Adam Drew on 9/7/25.
//

import SwiftUI

struct NoteListHeader: View {
    @Environment(TakeNoteVM.self) var takeNoteVM

    @State var inEditMode: Bool = false
    @State var newName : String = ""
    @FocusState var nameInputFocused: Bool

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
                if inEditMode {
                    TextField("Rename...", text: $newName)
                        .focused($nameInputFocused)
                        .onChange(of: nameInputFocused) { newValue in
                            if !newValue {
                                inEditMode = false
                                nameInputFocused = false
                            }
                        }
                        .onExitCommand {
                            inEditMode = false
                            nameInputFocused = false
                        }
                        .onSubmit {
                            guard let container = takeNoteVM.selectedContainer else {
                                return
                            }
                            container.name = newName
                            inEditMode.toggle()
                        }
                } else {
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
                }

                Text(noteCountLabel)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .contextMenu {
            if !inEditMode {
                Button("Rename") {
                    inEditMode.toggle()
                    nameInputFocused = inEditMode
                    newName = takeNoteVM.selectedContainer?.name ?? ""
                }
            }
        }

    }
}
