//
//  NoteListHeader.swift
//  TakeNote
//
//  Created by Adam Drew on 9/7/25.
//

import SwiftData
import SwiftUI

struct NoteListHeader: View {
    @Environment(TakeNoteVM.self) var takeNoteVM
    @Query() var allNotes: [Note]

    @State private var inEditMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool
    @State private var cachedNoteCount: Int = 0

    private func rebuildNoteCount() {
        guard let container = takeNoteVM.selectedContainer else {
            cachedNoteCount = 0
            return
        }
        if container.isAllNotes {
            cachedNoteCount = allNotes.filter {
                $0.folder?.isTrash != true && $0.folder?.isBuffer != true
            }.count
        } else {
            cachedNoteCount = container.notes.count
        }
    }

    var folderSymbol: String {
        guard let container = takeNoteVM.selectedContainer else {
            return "folder"
        }
        if container.isTrash {
            return "trash"
        }
        if container.isTag {
            return "tag.fill"
        }
        return container.symbol
    }

    var noteCountLabel: String {
        let noNotes = "No notes"
        guard takeNoteVM.selectedContainer != nil else {
            return noNotes
        }
        if cachedNoteCount == 0 {
            return noNotes
        }
        if cachedNoteCount == 1 {
            return "\(cachedNoteCount) note"
        }
        return "\(cachedNoteCount) notes"
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
                .foregroundStyle(takeNoteVM.selectedContainer?.getColor() ?? .takeNotePink)
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
                .background(
                    .regularMaterial
                )
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .onChange(of: allNotes) { _, _ in rebuildNoteCount() }
                .onChange(of: takeNoteVM.selectedContainer) { _, _ in rebuildNoteCount() }
                .onAppear { rebuildNoteCount() }
        }
    }
}
