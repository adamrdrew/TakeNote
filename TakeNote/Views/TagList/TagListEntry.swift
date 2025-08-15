//
//  TagListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

struct TagListEntry: View {
    var tag: NoteContainer
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @State var inDeleteMode: Bool = false
    var onDelete: ((_ deletedFolder: NoteContainer) -> Void) = {
        deletedFolder in
    }
    @State var inRenameMode: Bool = false
    @State var newTagName: String = ""
    @State var showColorPopover: Bool = false
    @FocusState private var nameInputFocused: Bool

    @State var newTagColor: Color = Color(.blue)

    func deleteTag() {
        modelContext.delete(tag)
        try? modelContext.save()
        onDelete(tag)
    }

    func startRename() {
        inRenameMode = true
        nameInputFocused = true
        newTagName = tag.name
    }

    func finishRename() {
        inRenameMode = false
        tag.name = newTagName
        try? modelContext.save()
    }

    func dropNoteToTag(_ wrappedIDs: [NoteIDWrapper]) {
        for wrappedID in wrappedIDs {
            let id = wrappedID.id
            // Find the note we're going to move by ID
            guard let note = modelContext.model(for: id) as? Note else {
                continue
            }
            // Add the destination tag to the note and save
            note.tag = tag
        }
        do {
            try modelContext.save()
        } catch {
            return
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if inRenameMode {
                TextField("New Tag Name", text: $newTagName)
                    .focused($nameInputFocused)
                    .onSubmit {
                        finishRename()
                    }
                    .onChange(of: nameInputFocused) { _, focused in
                        if !focused {
                            finishRename()
                        }
                    }
            } else {
                NoteLabelBadge(noteLabel: tag)
                Text(tag.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(colorScheme == .light ? Color.primary : Color.white)
                Spacer()
                HStack {
                    Text("\(tag.notes.count)")
                        .foregroundStyle(colorScheme == .light ? Color.primary : Color.white)
                    Image(systemName: "note.text")
                        .foregroundStyle(colorScheme == .light ? Color.primary : Color.white)
                }
            }
        }
        .popover(isPresented: $showColorPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tag Color").font(.headline)
                ColorPicker(
                    "Color",
                    selection: $newTagColor,
                    supportsOpacity: true
                )
                .labelsHidden()
                HStack {
                    Spacer()
                    Button("Cancel") { showColorPopover = false }
                    Button("Save") {
                        tag.setColor(newTagColor)
                        try? modelContext.save()
                        showColorPopover = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 260)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
        .dropDestination(for: NoteIDWrapper.self, isEnabled: true) {
            wrappedIDs,
            _ in
            dropNoteToTag(wrappedIDs)
        }
        .alert(
            "Are you sure you want to delete \(tag.name)?",
            isPresented: $inDeleteMode
        ) {
            Button("Delete", role: .destructive) {
                deleteTag()
            }
            Button("Cancel", role: .cancel) {
                inDeleteMode = false
            }
        }
        .contextMenu {
            Button(action: startRename) {
                Label("Rename Tag", systemImage: "pencil")
            }
            Button(action: {
                newTagColor = tag.getColor()
                showColorPopover = true
            }) {

                Label("Set Color", systemImage: "eyedropper")
            }
            if tag.canBeDeleted {
                Button(
                    role: .destructive,
                    action: {
                        inDeleteMode = true
                    }
                ) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
