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
    @StateObject private var search = SearchIndexService()

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
        Window("", id: "main-window") {
            ContentView()
                .environmentObject(search)
                .handlesExternalEvents(
                    preferring: ["takenote://"],
                    allowing: ["*"]
                )
        }
        .modelContainer(container)
        .windowToolbarStyle(.expanded)

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
        }
        .modelContainer(container)

        Window("TakeNote - AI Chat", id: "chat-window") {
            ChatWindow()
                .environmentObject(search)
        }
        .modelContainer(container)
        

    }
}
