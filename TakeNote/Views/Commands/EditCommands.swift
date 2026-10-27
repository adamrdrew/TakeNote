//
//  EditCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/24/25.
//

import os
import SwiftData
import SwiftUI
#if os(macOS)
    import AppKit
#endif

private let editCommandsLogger = Logger(subsystem: "com.adamdrew.takenote", category: "EditCommands")

struct EditCommands: Commands {
    @FocusedValue(\.containerDeleteRegistry) private var containerDeleteRegistry:
        CommandRegistry?
    @FocusedValue(\.containerRenameRegistry) private var containerRenameRegistry:
        CommandRegistry?

    @FocusedValue(\.selectedNoteContainer) private var selectedNoteContainer:
        NoteContainer?

    @FocusedValue(\.noteDeleteRegistry) private var noteDeleteRegistry: CommandRegistry?
    @FocusedValue(\.noteCopyMarkdownLinkRegistry) private var noteCopyMarkdownLinkRegistry: CommandRegistry?

    @FocusedValue(\.noteRenameRegistry) private var noteRenameRegistry: CommandRegistry?
    @FocusedValue(\.selectedNotes) private var selectedNotes: Set<Note>?

    @FocusedValue(\.noteStarToggleRegistry) private var noteStarToggleRegistry: CommandRegistry?

    @FocusedValue(\.tagSetColorRegistry) private var tagSetColorRegistry:
        CommandRegistry?

    @FocusedValue(\.noteEditorActions) private var noteEditorActions:
        NoteEditorActions?

    private var nothingEditableIsFocused: Bool {
        containerDeleteRegistry == nil && noteDeleteRegistry == nil
            && selectedNoteContainer == nil && selectedNotes == nil
    }

    private var selectedContainerIsPermanent: Bool {
        selectedNoteContainer?.isTrash == true || selectedNoteContainer?.isInbox == true
    }

    private var multipleNotesAreSelected: Bool {
        selectedNotes.map { $0.count != 1 } ?? false
    }

    private var noteIsInTrash: Bool {
        selectedNotes?.first?.folder?.isTrash == true
    }

    private var canRename: Bool {
        !nothingEditableIsFocused
            && !selectedContainerIsPermanent
            && !multipleNotesAreSelected
            && !noteIsInTrash
    }

    private var canDelete: Bool {
        !nothingEditableIsFocused
            && !selectedContainerIsPermanent
            && !noteIsInTrash
    }

    private var canSetColor: Bool {
        selectedNoteContainer?.isTag == true
    }

    private var canCopyMarkdownLink: Bool {
        noteCopyMarkdownLinkRegistry != nil && selectedNotes?.count == 1
    }

    var body: some Commands {
        #if os(macOS)
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Paste") {
                if noteEditorActions?.pasteImageFromMacOSClipboard() == true {
                    editCommandsLogger.info("Pasted image via Edit > Paste")
                } else {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
            }
            .keyboardShortcut("v", modifiers: .command)
        }
        #endif

        CommandGroup(after: .pasteboard) {
            Button("Rename", systemImage: "pencil") {
                if let selectedNoteContainer {
                    containerRenameRegistry?.runCommand(
                        id: selectedNoteContainer.persistentModelID
                    )
                }
                if let selectedNotes, let noteRenameRegistry {
                    for note in selectedNotes {
                        noteRenameRegistry.runCommand(id: note.persistentModelID)
                    }
                }
            }
            .disabled(!canRename)
            .keyboardShortcut("R", modifiers: [.command])

            Button("Copy Markdown Link", systemImage: "link.badge.plus") {
                editCommandsLogger.debug("copyMarkdownLink command invoked")
                if let note = selectedNotes?.first {
                    noteCopyMarkdownLinkRegistry?.runCommand(id: note.persistentModelID)
                }
            }
            .disabled(!canCopyMarkdownLink)
            .keyboardShortcut("C", modifiers: [.command, .option])

            Button("Delete", systemImage: "delete.left") {
                if let selectedNoteContainer {
                    containerDeleteRegistry?.runCommand(
                        id: selectedNoteContainer.persistentModelID
                    )
                }
                if let note = selectedNotes?.first {
                    noteDeleteRegistry?.runCommand(id: note.persistentModelID)
                }
            }
            .disabled(!canDelete)
            .keyboardShortcut(.delete, modifiers: [.command])

            Button("Set Color", systemImage: "paintpalette") {
                if selectedNoteContainer?.isTag == true, let selectedNoteContainer {
                    tagSetColorRegistry?.runCommand(
                        id: selectedNoteContainer.persistentModelID
                    )
                }
            }
            .disabled(!canSetColor)
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("MagicFormat", systemImage: "wand.and.sparkles") {
                noteEditorActions?.doMagicFormat()
            }
            .keyboardShortcut("f", modifiers: [.command, .option])
            .disabled(noteEditorActions == nil)

            Button("Magic Assistant", systemImage: "apple.intelligence") {
                noteEditorActions?.showAssistantPopover()
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(noteEditorActions?.textIsSelected != true)

            Button("Toggle Star", systemImage: "star") {
                if let selectedNotes, let noteStarToggleRegistry {
                    for note in selectedNotes {
                        noteStarToggleRegistry.runCommand(id: note.persistentModelID)
                    }
                }
            }
            .disabled(selectedNotes?.isEmpty != false)
            .keyboardShortcut("s", modifiers: [.command])

        }
    }
}
