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
    @State var newName: String = ""
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
        return container.symbol
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

    var ContainerNameEditor: some View {
        TextField("Rename...", text: $newName)
            .focused($nameInputFocused)
            .onChange(of: nameInputFocused) { _, newValue in
                if !newValue {
                    inEditMode = false
                    nameInputFocused = false
                }
            }
            #if os(macOS)
            .onExitCommand {
                inEditMode = false
                nameInputFocused = false
            }
            #endif
            .onSubmit {
                guard let container = takeNoteVM.selectedContainer
                else {
                    return
                }
                container.name = newName
                inEditMode.toggle()
            }
    }

    var NoteCountLabel: some View {
        Text(noteCountLabel)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    var ContainerNameLabel: some View {
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
    
    func toggleEditMode() {
        if !takeNoteVM.canRenameSelectedContainer {
            return
        }
        inEditMode.toggle()
        nameInputFocused = inEditMode
        newName = takeNoteVM.selectedContainer?.name ?? ""
    }

    var RenameButton: some View {
        Button("Rename") {
            toggleEditMode()
        }
    }

    var Header: some View {
        HStack {
            VStack(alignment: .leading) {
                if inEditMode {
                    ContainerNameEditor
                } else {
                    ContainerNameLabel
                }
                NoteCountLabel
            }
            Spacer()
        }
        .padding()
        .onTapGesture(count: 1) {
           toggleEditMode()
        }
        .contextMenu {
            if !inEditMode && takeNoteVM.canRenameSelectedContainer {
                RenameButton
            }
        }
    }

    var body: some View {
        if takeNoteVM.selectedContainer != nil {
            Header
        }
    }
}
