//
//  WindowCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/25/25.
//

import SwiftUI

struct WindowCommands : Commands {
    
    @FocusedValue(\.chatEnabled) var chatEnabled : Bool?
    @FocusedValue(\.openChatWindow) var openChatWindow : (() -> Void)?
    @FocusedValue(\.noteOpenEditorWindowRegistry) var noteOpenEditorWindowRegistry : CommandRegistry?
    @FocusedValue(\.selectedNotes) var selectedNotes: Set<Note>?

    var openEditorWindowDisabled: Bool {
        guard let sn = selectedNotes, sn.count == 1 else {
            return true
        }
        guard let oewr = noteOpenEditorWindowRegistry else {
            return true
        }
        return false
    }
    
    var chatDisabled: Bool {
        if let ce = chatEnabled {
            return !ce
        }
        return true
    }
    
    var body : some Commands {
        CommandGroup(after: .windowList) {
            Button("Open Chat", systemImage: "message") {
                if let ocw = openChatWindow {
                    ocw()
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(chatDisabled)
            
            Button("Open Editor Window", systemImage: "macwindow.badge.plus") {
                guard let sn = selectedNotes, sn.count == 1 else {
                    return
                }
                guard let selectedNote = sn.first else {
                    return
                }
                if let oew = noteOpenEditorWindowRegistry {
                    oew.runCommand(id: selectedNote.persistentModelID)
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(openEditorWindowDisabled)
            
        }
    }
}
