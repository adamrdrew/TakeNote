//
//  EditCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

import SwiftData
import SwiftUI

struct EditCommands: Commands {
    @FocusedValue(\.containerDeleteRegistry) var containerDeleteRegistry:
        CommandRegistry?
    @FocusedValue(\.containerRenameRegistry) var containerRenameRegistry:
        CommandRegistry?
    @FocusedValue(\.selectedNoteContainer) var selectedNoteContainer:
        NoteContainer?

    @FocusedValue(\.noteDeleteRegistry) var noteDeleteRegistry: CommandRegistry?
    @FocusedValue(\.noteRenameRegistry) var noteRenameRegistry: CommandRegistry?
    @FocusedValue(\.selectedNotes) var selectedNotes: Set<Note>?

    @FocusedValue(\.tagSetColorRegistry) var tagSetColorRegistry:
        CommandRegistry?
    
    @FocusedValue(\.togglePreview) var togglePreview : (() -> Void)?
    
    var nothingEditableIsFocused : Bool {
        return containerDeleteRegistry == nil && noteDeleteRegistry == nil && selectedNoteContainer == nil && selectedNotes == nil
    }
 
    var selectedContainerIsPermanent: Bool {
        if let snc = selectedNoteContainer {
            return snc.isTrash || snc.isInbox
        }
        return false
    }
    
    var multipleNotesAreSelected: Bool {
        if let sn = selectedNotes {
            return sn.count != 1
        }
        return false
    }
    
    var noteIsInTrash: Bool {
        if let sn = selectedNotes {
            if let note = sn.first {
                return note.folder.isTrash
            }
        }
        return false
    }
    
    
    var canRename: Bool {
        if nothingEditableIsFocused {
            return false
        }
        if selectedContainerIsPermanent {
            return false
        }
        if multipleNotesAreSelected {
            return false
        }
        if noteIsInTrash {
            return false
        }
        return true
    }
    
    var canDelete: Bool {
        if nothingEditableIsFocused {
            return false
        }
        if selectedContainerIsPermanent {
            return false
        }
        if noteIsInTrash {
            return false
        }
        return true
    }
    
    var canSetColor: Bool {
        if let sc = selectedNoteContainer {
            return sc.isTag
        }
        return false
    }

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Rename", systemImage: "pencil") {
                if let sc = selectedNoteContainer {
                    if let dr = containerRenameRegistry {
                        dr.runCommand(id: sc.id)
                    }
                }
                if let sn = selectedNotes {
                    if let nrr = noteRenameRegistry {
                        for note in sn {
                            nrr.runCommand(id: note.id)
                        }
                    }
                }
            }
            .disabled(!canRename)
            .keyboardShortcut("R", modifiers: [.command])

            Button("Delete", systemImage: "delete.left") {
                if let sc = selectedNoteContainer {
                    if let rr = containerDeleteRegistry {
                        rr.runCommand(id: sc.id)
                    }
                }
                if let sn = selectedNotes {
                    if let ndr = noteDeleteRegistry {
                        for note in sn {
                            ndr.runCommand(id: note.id)
                        }
                    }
                }
            }
            .disabled(!canDelete)
            .keyboardShortcut(.delete, modifiers: [.command])
            
            Button("Set Color", systemImage: "paintpalette") {
                if let sc = selectedNoteContainer {
                    if sc.isTag {
                        if let tsc = tagSetColorRegistry {
                            tsc.runCommand(id: sc.id)
                        }
                    }
                }
            }
            .disabled(!canSetColor)
            .keyboardShortcut("c", modifiers: [.command, .option])
            
            Button("Toggle Preview", systemImage: "eye") {
                if let tp = togglePreview {
                    tp()
                }
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(togglePreview == nil)

        }
    }
}
