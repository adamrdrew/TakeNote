//
//  ViewCommands.swift
//  TakeNote
//
//  Created by Adam Drew on 8/28/25.
//

import SwiftUI

struct ViewCommands: Commands {
    @FocusedValue(\.togglePreview) var togglePreview: (() -> Void)?
    @FocusedValue(\.showBacklinks) private var showBacklinks: (() -> Void)?
    @FocusedValue(\.openNoteHasBacklinks) private var openNoteHasBacklinks:
        Bool?

    var backlinksCommandDisabled: Bool {
        if showBacklinks == nil || openNoteHasBacklinks == nil {
            return true
        }
        return openNoteHasBacklinks! == false
    }

    var body: some Commands {
        CommandGroup(after: .sidebar) {

            Button("Backlinks", systemImage: "link") {
                guard let sb = showBacklinks else { return }
                sb()
            }
            .disabled(backlinksCommandDisabled)
            .keyboardShortcut("B", modifiers: [.command, .option])

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
