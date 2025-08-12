//
//  TakeNoteApp.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

@main
struct TakeNoteApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Note.self,
                NoteContainer.self,
                configurations: {
                    let config = ModelConfiguration(isStoredInMemoryOnly: true)
                    return config
                }()
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
            .handlesExternalEvents(preferring: ["takenote://"], allowing: ["*"])
        }
        .modelContainer(container)

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
        }
        .modelContainer(container)

    }
}
