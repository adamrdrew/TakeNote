//
//  EditCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

import SwiftUI
import SwiftData

struct EditCommands: Commands {
    @FocusedValue(\.containerDeleteRegistry) var containerDeleteRegistry: CommandRegistry?
    @FocusedValue(\.containerRenameRegistry) var containerRenameRegistry: CommandRegistry?

    
    @FocusedValue(\.selectedNoteContainer) var selectedNoteContainer: NoteContainer?
    
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Rename", systemImage: "pencil") {
                if let sc = selectedNoteContainer {
                    if let dr = containerRenameRegistry {
                        dr.runCommand(id: sc.id)
                    }
                }
            }
            .disabled(
                containerRenameRegistry == nil || selectedNoteContainer == nil || selectedNoteContainer!.isTrash || selectedNoteContainer!.isInbox
            )
            .keyboardShortcut("R", modifiers: [.command])
            
            Button("Delete", systemImage: "delete.left") {
                if let sc = selectedNoteContainer {
                    if let rr = containerDeleteRegistry {
                        rr.runCommand(id: sc.id)
                    }
                }
            }
            .disabled(
                containerDeleteRegistry == nil || selectedNoteContainer == nil || selectedNoteContainer!.isTrash || selectedNoteContainer!.isInbox
            )
            .keyboardShortcut(.delete, modifiers: [.command])
            

            
            
        }
    }
}
