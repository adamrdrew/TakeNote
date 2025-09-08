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
    @Entry var showDeleteEverything: (() -> Void)?
}

struct MainWindow: View {
    @Environment(\.openWindow) var openWindow
    @Environment(\.modelContext) var modelContext
    @Environment(TakeNoteVM.self) var takeNoteVM

    @Query() var notes: [Note]
    @Query() var containers: [NoteContainer]
    @Query() var noteLinks: [NoteLink]

    @State var notesInBufferMessagePresented: Bool = false
    @State var showDeleteEverythingAlert: Bool = false

    @State var showChatPopover: Bool = false

    func showDeleteEverything() {
        showDeleteEverythingAlert = true
    }

    func doShowChatPopover() {
        showChatPopover.toggle()
    }

    @MainActor
    func openChatWindow() {
        openWindow(id: TakeNoteVM.chatWindowID)
    }

    var chatEnabled: Bool {
        return takeNoteVM.aiIsAvailable && notes.count > 0
    }

    func deleteEverything() {
        for note in notes {
            modelContext.delete(note)
        }
        for container in containers {
            modelContext.delete(container)
        }
        for noteLink in noteLinks {
            modelContext.delete(noteLink)
        }
        try? modelContext.save()
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        NavigationSplitView {
            Sidebar()
            #if os(iOS)
                .navigationTitle(
                    Text("TakeNote")
                )
            #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            takeNoteVM.addFolder(modelContext)
                        }) {
                            Label(
                                "Add Folder",
                                systemImage: "folder.badge.plus"
                            )
                        }
                        .help("Add Folder")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        AddTagButton(action: {
                            takeNoteVM.addTag(modelContext: modelContext)
                        })
                    }

                }
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
                    if chatFeatureFlagEnabled {
                        #if os(macOS)
                            if chatEnabled {
                                Button(action: openChatWindow) {
                                    Label("Chat", systemImage: "message")
                                }
                                .help("AI Chat")
                            }
                        #endif
                        #if os(iOS)
                            if chatEnabled {
                                Button(action: doShowChatPopover) {
                                    Label("Chat", systemImage: "message")
                                }
                                .help("AI Chat")
                                .popover(
                                    isPresented: $showChatPopover,
                                    arrowEdge: .trailing
                                ) {
                                    ChatWindow()
                                }
                            }
                        #endif
                    }
                    if takeNoteVM.canEmptyTrash {
                        Button(action: takeNoteVM.showEmptyTrashAlert) {
                            Label("Empty Trash", systemImage: "trash.slash")
                        }
                        .help("Empty Trash")
                    }

                }
        } detail: {
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
            "Do you want to delete everything?",
            isPresented: $showDeleteEverythingAlert
        ) {
            Button(
                "Delete",
                role: .destructive,
                action: {
                    deleteEverything()

                    takeNoteVM.trashFolder = nil
                    takeNoteVM.inboxFolder = nil
                    takeNoteVM.bufferFolder = nil

                    takeNoteVM.folderInit(modelContext)
                }
            )
        }
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
        .focusedSceneValue(\.showDeleteEverything, showDeleteEverything)
        .alert(
            "Something went wrong: \(takeNoteVM.errorAlertMessage)",
            isPresented: $takeNoteVM.errorAlertIsVisible
        ) {
            Button("OK", action: { takeNoteVM.errorAlertIsVisible = false })
        }
        .alert(
            "\(takeNoteVM.bufferNotesCount) notes found in the cut and paste buffer. They'll be returned to your Inbox.",
            isPresented: $notesInBufferMessagePresented
        ) {
            Button("OK", action: { notesInBufferMessagePresented = false })

        }
        .onAppear(perform: {
            takeNoteVM.trashFolder = containers.first(where: { $0.isTrash })
            takeNoteVM.inboxFolder = containers.first(where: { $0.isInbox })
            takeNoteVM.bufferFolder = containers.first(where: { $0.isBuffer })

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
