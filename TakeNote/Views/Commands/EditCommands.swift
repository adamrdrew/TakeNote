//
//  EditCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

import SwiftUI
import SwiftData

struct EditCommands: Commands {
    @FocusedValue(\.folderItemController) var folderItemController: FolderItemController?
    @FocusedValue(\.selectedNoteContainer) var selectedNoteContainer: NoteContainer?
    
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Rename Folder", systemImage: "folder") {
                if let selectedFolder = selectedNoteContainer {
                    if let fc = folderItemController {
                        fc.runRenameCommand(id: selectedFolder.id)
                    }
                }
            }
            .disabled(
                folderItemController == nil || selectedNoteContainer == nil || selectedNoteContainer!.isTrash || selectedNoteContainer!.isInbox
            )
            .keyboardShortcut("R", modifiers: [.command])
        }
    }
}
