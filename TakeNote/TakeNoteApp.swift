//
//  TakeNoteApp.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI
import os

private let onboardingVersionCurrent = 1
private let onboardingVersionKey = "onboarding.version.seen"

@main
struct TakeNoteApp: App {
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false

    @FocusedValue(\.sidebarCommands) var sidebarCommands

    
    let container: ModelContainer
    @StateObject private var search = SearchIndexService()
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "App")

    init() {
        do {
            container = try ModelContainer(
                for: Note.self,
                NoteContainer.self,
                configurations: {
                    #if DEBUG
                        let config = ModelConfiguration(
                            isStoredInMemoryOnly: true
                        )
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
                .sheet(isPresented: $showOnboarding) {
                    WelcomeView {
                        onboardingVersionSeen = onboardingVersionCurrent
                        #if DEBUG
                            onboardingVersionSeen = 0
                        #endif
                        showOnboarding = false
                    }
                }
                .task {
                    showOnboarding =
                        onboardingVersionSeen < onboardingVersionCurrent
                }
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
                Button("Add Folder"){
                    sidebarCommands?.addFolder()
                }
                .disabled(sidebarCommands == nil)
                Button("Add Tag"){
                    sidebarCommands?.addTag()
                }
                .disabled(sidebarCommands == nil)
                Button("Rebuild Search Index") {
                    do {
                        let notes = try ModelContext(container).fetch(
                            FetchDescriptor<Note>()
                        )
                        if notes.isEmpty {
                            logger.debug("No notes to reindex.")
                            return
                        }
                        search.dropAll()
                        search.reindexAll(notes)
                        logger.debug("Rebuilt search index")
                    } catch {
                        logger.error(
                            "Search index rebuild failed: \(error.localizedDescription)"
                        )
                    }

                }
                .disabled(search.isIndexing)
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
