//
//  NoteListHeader.swift
//  TakeNote
//
//  Created by Adam Drew on 9/7/25.
//

import SwiftData
import SwiftUI

struct NoteListHeader: View {
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Query() private var allNotes: [Note]

    @State private var inEditMode: Bool = false
    @State private var newName: String = ""
    @FocusState private var nameInputFocused: Bool

    private func noteCount(for container: NoteContainer) -> Int {
        if container.isAllNotes {
            return allNotes.filter {
                $0.folder?.isTrash != true && $0.folder?.isBuffer != true
            }.count
        }
        return container.notes.count
    }

    private func folderSymbol(for container: NoteContainer) -> String {
        if container.isTrash {
            return "trash"
        }
        if container.isTag {
            return "tag.fill"
        }
        return container.symbol
    }

    var body: some View {
        if let selectedContainer = takeNoteVM.selectedContainer {
            NoteListHeaderContent(
                container: selectedContainer,
                canRename: takeNoteVM.canRenameSelectedContainer,
                noteCount: noteCount(for: selectedContainer),
                folderSymbol: folderSymbol(for: selectedContainer),
                inEditMode: $inEditMode,
                newName: $newName,
                nameInputFocused: $nameInputFocused
            )
                #if !os(visionOS)
                .glassEffect(in: .rect)
                #endif
        }
    }
}

private struct NoteListHeaderContent: View {
    let container: NoteContainer
    let canRename: Bool
    let noteCount: Int
    let folderSymbol: String
    @Binding var inEditMode: Bool
    @Binding var newName: String
    let nameInputFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if inEditMode {
                    NoteListHeaderNameEditor(
                        container: container,
                        inEditMode: $inEditMode,
                        newName: $newName,
                        nameInputFocused: nameInputFocused
                    )
                } else {
                    NoteListHeaderNameLabel(
                        name: container.name,
                        symbol: folderSymbol,
                        color: container.getColor()
                    )
                }
                NoteListHeaderCountLabel(noteCount: noteCount)
            }
            Spacer()
        }
        .padding()
        .onTapGesture(count: 1) {
            toggleEditMode()
        }
        .contextMenu {
            if !inEditMode && canRename {
                NoteListHeaderRenameButton(action: toggleEditMode)
            }
        }
    }

    private func toggleEditMode() {
        guard canRename else { return }
        inEditMode.toggle()
        nameInputFocused.wrappedValue = inEditMode
        newName = container.name
    }
}

private struct NoteListHeaderNameEditor: View {
    let container: NoteContainer
    @Binding var inEditMode: Bool
    @Binding var newName: String
    let nameInputFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField("Rename...", text: $newName)
            .focused(nameInputFocused)
            .onChange(of: nameInputFocused.wrappedValue) { _, newValue in
                if !newValue {
                    inEditMode = false
                    nameInputFocused.wrappedValue = false
                }
            }
            #if os(macOS)
                .onExitCommand {
                    inEditMode = false
                    nameInputFocused.wrappedValue = false
                }
            #endif
            .onSubmit {
                container.name = newName
                inEditMode.toggle()
            }
    }
}

private struct NoteListHeaderNameLabel: View {
    let name: String
    let symbol: String
    let color: Color

    var body: some View {
        Label {
            Text(name)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
        .font(.title)
        .fontWeight(.bold)
    }
}

private struct NoteListHeaderCountLabel: View {
    let noteCount: Int

    var body: some View {
        countText
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private var countText: Text {
        if noteCount == 0 {
            Text("No notes")
        } else if noteCount == 1 {
            Text("1 note")
        } else {
            Text(
                "\(noteCount, format: .number) notes",
                comment: "Header count for a note list; the variable is the number of notes."
            )
        }
    }
}

private struct NoteListHeaderRenameButton: View {
    let action: () -> Void

    var body: some View {
        Button("Rename", action: action)
    }
}
