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
    @Environment(SearchIndexService.self) private var search

    @Query() var notes: [Note]
    @Query() var containers: [NoteContainer]
    @Query() var noteLinks: [NoteLink]

    @State var notesInBufferMessagePresented: Bool = false
    @State var showDeleteEverythingAlert: Bool = false

    @State private var preferredColumn = NavigationSplitViewColumn.sidebar

    @State var showChatPopover: Bool = false
    @State var showSortPopover: Bool = false

    var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
            return UIDevice.current.userInterfaceIdiom == .phone
                ? .bottomBar : .automatic
        #else
            return .automatic
        #endif
    }

    func showDeleteEverything() {
        showDeleteEverythingAlert = true
    }

    func doShowChatPopover() {
        showChatPopover.toggle()
    }

    func doShowSortPopover() {
        showSortPopover.toggle()
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

    var NoteListToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            if takeNoteVM.canAddNote {
                Button(action: {
                    if let newNote = takeNoteVM.addNote(modelContext) {
                        search.reindex(note: newNote)
                    }
                }) {
                    Image(systemName: "note.text.badge.plus")
                }
                .help("Add Note")
            }
            if !(takeNoteVM.selectedContainer?.notes.isEmpty ?? false) {
                Button(action: doShowSortPopover) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .help("Sort Notes")
                .popover(
                    isPresented: $showSortPopover,
                    attachmentAnchor: .point(.center),
                    arrowEdge: .bottom
                ) {
                    NoteSortPopover()
                }
            }
            if chatFeatureFlagEnabled && chatEnabled {
                #if os(macOS)
                    Button(action: openChatWindow) {
                        Label("Chat", systemImage: "message")
                    }
                    .help("AI Chat")
                #endif
                #if os(iOS)
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
                #endif
            }
            if takeNoteVM.canEmptyTrash {
                Button(action: takeNoteVM.showEmptyTrashAlert) {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
                .help("Empty Trash")
            }
        }
    }

    var navTitle: String {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                return "TakeNote"
            } else {
                return ""
            }
        #else
            return ""
        #endif
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM

        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            VStack {
                Sidebar()
                    #if os(iOS)
                        .navigationTitle(
                            Text(navTitle)
                        )
                    #endif
                    .toolbar {
                        ToolbarItem(placement: toolbarPlacement) {

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
                        ToolbarItem(placement: toolbarPlacement) {
                            AddTagButton(action: {
                                takeNoteVM.addTag(modelContext: modelContext)
                            })
                        }

                    }
            }
        } content: {
            NoteList()
                .toolbar {
                    #if os(iOS)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    #endif
                    NoteListToolbar
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
                    takeNoteVM.starredFolder = nil

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
                    let trashNoteIDs = takeNoteVM.trashFolder?.notes.map { $0.uuid } ?? []
                    takeNoteVM.emptyTrash(modelContext)
                    for noteID in trashNoteIDs {
                        search.deleteFromIndex(noteID: noteID)
                    }
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
