//
//  NewNoteControl.swift
//  NewNoteControl
//
//  Created by Adam Drew on 9/20/25.
//

import WidgetKit
import SwiftUI


struct NewNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.adamdrew.takenote.newNoteControl"
        ) {
            ControlWidgetButton(action: NewNoteIntent()) {
                Label("New Note", systemImage: "document.badge.plus")
            }
        }
        .displayName("New Note")
        .description("Create a new note in your Inbox.")
    }
}



