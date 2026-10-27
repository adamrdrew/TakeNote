//
//  ViewCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/28/25.
//

import SwiftUI

struct ViewCommands: Commands {
    @FocusedValue(\.noteEditorActions) private var noteEditorActions:
        NoteEditorActions?

    private var backlinksCommandDisabled: Bool {
        noteEditorActions?.openNoteHasBacklinks != true
    }

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Backlinks", systemImage: "link") {
                noteEditorActions?.showBacklinks()
            }
            .disabled(backlinksCommandDisabled)
            .keyboardShortcut("B", modifiers: [.command, .option])

            Button("Toggle Preview", systemImage: "eye") {
                noteEditorActions?.togglePreview()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(noteEditorActions == nil)
        }
    }
}
