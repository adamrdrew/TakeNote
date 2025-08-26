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

    private var search = SearchIndexService()
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "App")

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
        #if DEBUG
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                inMemory: true,
                isAutosaveEnabled: true,
                isUndoEnabled: false,
            )
        #else
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                isAutosaveEnabled: true,
                isUndoEnabled: false
            )
        #endif
        .windowToolbarStyle(.expanded)
        .commands {
            FileCommands()
            EditCommands()
            WindowCommands()
        }

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
        }
        #if DEBUG
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                inMemory: true,
                isAutosaveEnabled: true,
                isUndoEnabled: false,
            )
        #else
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                isAutosaveEnabled: true,
                isUndoEnabled: false
            )
        #endif
        .environment(search)
        .environment(TakeNoteVM())

        Window("TakeNote - AI Chat", id: "chat-window") {
            ChatWindow()
                .environment(search)
        }
        #if DEBUG
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                inMemory: true,
                isAutosaveEnabled: true,
                isUndoEnabled: false,
            )
        #else
            .modelContainer(
                for: [Note.self, NoteContainer.self],
                isAutosaveEnabled: true,
                isUndoEnabled: false
            )
        #endif
        .environment(search)
        .environment(TakeNoteVM())

    }

}
