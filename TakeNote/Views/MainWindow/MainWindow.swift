//
//  MainWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

extension FocusedValues {
    @Entry var chatEnabled: Bool?
    @Entry var openChatWindow: (() -> Void)?
}

struct MainWindow: View {
    @Environment(\.openWindow) var openWindow
    @Environment(\.modelContext) var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM
    
    @Query() var notes: [Note]
    
    @State var notesInBufferMessagePresented : Bool = false
    
    @MainActor
    func openChatWindow() {
        openWindow(id: TakeNoteVM.chatWindowID)
    }
    
    var chatEnabled : Bool {
        return takeNoteVM.aiIsAvailable && notes.count > 0
    }
    
    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        NavigationSplitView {
            Sidebar()
        } content: {
            NoteList()
                .toolbar {
                    if takeNoteVM.canAddNote {
                        Button(action: {
                            takeNoteVM.addNote(modelContext)
                        }) {
                            Image(systemName: "note.text.badge.plus")
                        }
                        .help("Add Note")
                    }
                    if chatEnabled {
                        Button(action: openChatWindow) {
                            Label("Chat", systemImage: "message")
                        }
                        .help("AI Chat")
                    }
                    if takeNoteVM.canEmptyTrash {
                        Button(action: takeNoteVM.showEmptyTrashAlert) {
                            Label("Empty Trash", systemImage: "trash.slash")
                        }
                        .help("Empty Trash")
                    }
                    
                }
        }
        detail: {
            if takeNoteVM.showMultiNoteView {
                MultiNoteViewer()
                    .transition(.opacity)
            } else {
                NoteEditor(
                    openNote: $takeNoteVM.openNote,
                )
                .transition(.opacity)
            }
        }
        .onChange(of: takeNoteVM.multipleNotesSelected) { _, newValue in
            withAnimation {
                takeNoteVM.showMultiNoteView = newValue
            }
        }
        #if os(macOS)
        .background(Color(NSColor.textBackgroundColor))
        #endif
        #if os(iOS)
        .background(Color(UIColor.systemBackground))
        #endif
        .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300)
        .navigationTitle(takeNoteVM.navigationTitle)
        .alert(
            "Link Error: \(takeNoteVM.linkToNoteErrorMessage)",
            isPresented: $takeNoteVM.linkToNoteErrorIsPresented
        ) {
            Button(
                "OK",
                action: { takeNoteVM.linkToNoteErrorIsPresented = false }
            )
        }
        .alert(
            "Are you sure you want to empty the trash? This action cannot be undone.",
            isPresented: $takeNoteVM.emptyTrashAlertIsPresented
        ) {
            Button(
                "Empty Trash",
                role: .destructive,
                action: {
                    takeNoteVM.emptyTrash(modelContext)
                }
            )
        }
        .focusedSceneValue(\.modelContext, modelContext)
        .focusedSceneValue(\.chatEnabled, chatEnabled)
        .focusedSceneValue(\.openChatWindow, openChatWindow)
        .alert(
            "Something went wrong: \(takeNoteVM.errorAlertMessage)",
            isPresented: $takeNoteVM.errorAlertIsVisible
        ) {
            Button("OK", action: { takeNoteVM.errorAlertIsVisible = false })
        }
        .alert("\(takeNoteVM.bufferNotesCount) notes found in the cut and paste buffer. They'll be returned to your Inbox.", isPresented: $notesInBufferMessagePresented) {
            Button("OK", action: { notesInBufferMessagePresented = false })

        }
        .onAppear(perform: {
            takeNoteVM.folderInit(modelContext)
            if !takeNoteVM.bufferIsEmpty {
                notesInBufferMessagePresented = true
                takeNoteVM.moveNotesFromBufferToInbox(modelContext)
            }
            
        })
        .onOpenURL(perform: { url in
            takeNoteVM.loadNoteFromURL(url, modelContext: modelContext)
        })
    }
    
}

#Preview {
    MainWindow()
}
