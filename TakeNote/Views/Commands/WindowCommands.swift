//
//  WindowCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/25/25.
//

import SwiftData
import SwiftUI

struct WindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.chatEnabled) private var chatEnabled: Bool?
    @FocusedValue(\.noteOpenEditorWindowRegistry)
    private var noteOpenEditorWindowRegistry: CommandRegistry?
    @FocusedValue(\.selectedNotes) private var selectedNotes: Set<Note>?

    private var openEditorWindowDisabled: Bool {
        selectedNotes?.count != 1 || noteOpenEditorWindowRegistry == nil
    }

    private var chatDisabled: Bool {
        chatEnabled != true
    }

    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            if chatFeatureFlagEnabled {
                Button("Open Chat", systemImage: "message") {
                    openWindow(id: TakeNoteVM.chatWindowID)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(chatDisabled)
            }

            Button("Open Editor Window", systemImage: "macwindow.badge.plus") {
                guard let selectedNote = selectedNotes?.first else {
                    return
                }
                noteOpenEditorWindowRegistry?.runCommand(
                    id: selectedNote.persistentModelID
                )
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(openEditorWindowDisabled)
        }
    }
}
