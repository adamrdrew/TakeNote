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
    
    var chatDisabled: Bool {
        if let ce = chatEnabled {
            return !ce
        }
        return true
    }
    
    var body : some Commands {
        CommandGroup(after: .windowList) {
            Button("Chat", systemImage: "message") {
                if let ocw = openChatWindow {
                    ocw()
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(chatDisabled)
            
        }
    }
}
