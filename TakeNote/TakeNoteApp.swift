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
    @Environment(\.modelContext) var modelContext
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false
    var takeNoteVM = TakeNoteVM()

    let container: ModelContainer
    private var search = SearchIndexService()
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
                .handlesExternalEvents(
                    preferring: ["takenote://"],
                    allowing: ["*"]
                )
                .focusedSceneValue(takeNoteVM)
                .focusedSceneValue(search)
        }
        .environment(takeNoteVM)
        .environment(search)
        .modelContainer(container)
        .windowToolbarStyle(.expanded)
        .commands {
            FileCommands()
        }

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
        }
        .modelContainer(container)
        .environment(TakeNoteVM())

        Window("TakeNote - AI Chat", id: "chat-window") {
            ChatWindow()
                .environment(search)
        }
        .modelContainer(container)

    }
    
}
