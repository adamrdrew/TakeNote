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
                    #if DEBUG
                    let config = ModelConfiguration(isStoredInMemoryOnly: true)
                    #else
                    let config = ModelConfiguration()
                    #endif
                    return config
                }()
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        Window("", id: "main-window") {
            MainWindow()
                .environmentObject(search)
                .handlesExternalEvents(
                    preferring: ["takenote://"],
                    allowing: ["*"]
                )
        }
        .modelContainer(container)
        .windowToolbarStyle(.expanded)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Rebuild Search Index") {
                    search.dropAll()
                    var notes = try? ModelContext(container).fetch(FetchDescriptor<Note>())
                    search.reindexAll(notes ?? [])
                    
                }
            }
        }


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
