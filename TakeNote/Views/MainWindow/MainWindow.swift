//
//  MainWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI
import os
import CoreSpotlight

@MainActor
@Observable
final class MainWindowActions {
    var deleteEverythingAlertIsPresented = false

    func showDeleteEverything() {
        deleteEverythingAlertIsPresented = true
    }
}

private struct NoteListToolbarContent: ToolbarContent {
    @Environment(\.openWindow) private var openWindow
    let toolbarPlacement: ToolbarItemPlacement
    let takeNoteVM: TakeNoteVM
    let modelContext: ModelContext
    let search: SearchIndexService
    let chatEnabled: Bool
    @Binding var showSortPopover: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: toolbarPlacement) {
            if takeNoteVM.canAddNote {
                Button {
                    if let newNote = takeNoteVM.addNote(modelContext) {
                        search.reindex(note: newNote)
                    }
                } label: {
                    Image(systemName: "note.text.badge.plus")
                }
                .help("Add Note")
            }
            if takeNoteVM.selectedContainer?.notes.isEmpty == false {
                Button {
                    showSortPopover.toggle()
                } label: {
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
                    Button {
                        openWindow(id: TakeNoteVM.chatWindowID)
                    } label: {
                        Label("Chat", systemImage: "message")
                    }
                    .help("Magic Chat")
                #endif
            }
            if takeNoteVM.canEmptyTrash {
                Button(action: takeNoteVM.showEmptyTrashAlert) {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
                .help("Empty Trash")
            }
        }
        .visibilityPriority(.high)
    }
}

struct MainWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Environment(SearchIndexService.self) private var search

    @Query() private var notes: [Note]
    @Query() private var containers: [NoteContainer]
    @Query() private var noteLinks: [NoteLink]
    @Query() private var noteImages: [NoteImage]

    static let logger = Logger(subsystem: "com.adamdrew.takenote", category: "MainWindow")

    @State private var notesInBufferMessagePresented: Bool = false
    @State private var mainWindowActions = MainWindowActions()
    @State private var preferredColumn = NavigationSplitViewColumn.sidebar
    @State private var showSidebarChatPopover: Bool = false
    @State private var showSortPopover: Bool = false

    private let sidebarColumnWidth: CGFloat = 360

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
            return isCompactLayout ? .bottomBar : .automatic
        #else
            return .automatic
        #endif
    }

    private func doShowSidebarChatPopover() {
        showSidebarChatPopover.toggle()
    }

    private var chatEnabled: Bool {
        takeNoteVM.aiIsAvailable && notes.count > 0
    }

    private func deleteEverything() {
        for note in notes {
            modelContext.delete(note)
        }
        for container in containers {
            modelContext.delete(container)
        }
        for noteLink in noteLinks {
            modelContext.delete(noteLink)
        }
        for image in noteImages {
            modelContext.delete(image)
        }
        do {
            try modelContext.save()
            search.deleteAllFromIndex()
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
        }
    }

    private var navTitle: LocalizedStringResource {
        #if os(iOS)
            isCompactLayout ? "TakeNote" : ""
        #else
            ""
        #endif
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        @Bindable var mainWindowActions = mainWindowActions

        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            VStack {
                Sidebar()

                    #if os(iOS)
                        .navigationTitle(
                            Text(navTitle)
                        )
                    #endif
                    .toolbar {
                        #if os(iOS)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.flexible, placement: .bottomBar)
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
                        .visibilityPriority(.high)
                        ToolbarItem(placement: toolbarPlacement) {
                            AddTagButton(action: {
                                takeNoteVM.addTag(modelContext: modelContext)
                            })
                        }
                        .visibilityPriority(.high)
                        #endif
                        #if os(iOS)
                        if chatFeatureFlagEnabled && chatEnabled {
                            ToolbarItem(placement: toolbarPlacement) {
                                Button(action: doShowSidebarChatPopover) {
                                    Label("Chat", systemImage: "message")
                                }
                                .help("Magic Chat")
                                .adaptivePopover(
                                    isPresented: $showSidebarChatPopover,
                                    arrowEdge: .trailing
                                ) {
                                    ChatWindow()
                                    .frame(minWidth: 400, minHeight: 500)
                                }
                            }
                            .visibilityPriority(.high)
                        }
                        #endif

                    }
                    .navigationSplitViewColumnWidth(
                        min: sidebarColumnWidth,
                        ideal: sidebarColumnWidth,
                        max: sidebarColumnWidth
                    )
            }
        } content: {
            NoteList()
                .toolbar {
                    #if os(iOS)
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    #endif
                    NoteListToolbarContent(
                        toolbarPlacement: toolbarPlacement,
                        takeNoteVM: takeNoteVM,
                        modelContext: modelContext,
                        search: search,
                        chatEnabled: chatEnabled,
                        showSortPopover: $showSortPopover
                    )
                }

        } detail: {
            if takeNoteVM.multipleNotesSelected {
                MultiNoteViewer()
                    .transition(.opacity)
            } else {
                NoteEditor(
                    openNote: $takeNoteVM.openNote,
                )
                .transition(.opacity)
            }
        }
        .animation(.default, value: takeNoteVM.multipleNotesSelected)
        #if os(macOS)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: {
                        takeNoteVM.addFolder(modelContext)
                    }) {
                        Label(
                            "Add Folder",
                            systemImage: "folder.badge.plus"
                        )
                    }
                    .help("Add Folder")

                    AddTagButton(action: {
                        takeNoteVM.addTag(modelContext: modelContext)
                    })
                }
                .visibilityPriority(.high)
            }
        #endif
        .searchable(text: $takeNoteVM.noteSearchText)
        #if os(iOS)
        .onSubmit(of: .search) {
            takeNoteVM.searchSubmitted()
        }
        #endif
        #if os(macOS)
            .background {
                Color(nsColor: NSColor.textBackgroundColor)
            }
        #endif
        #if os(iOS)
            .background {
                Color(uiColor: UIColor.systemBackground)
            }
        #endif
        .navigationTitle(takeNoteVM.navigationTitle)
        .alert(
            "Do you want to delete everything?",
            isPresented: $mainWindowActions.deleteEverythingAlertIsPresented
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

                    takeNoteVM.folderInit(
                        modelContext,
                        selectInboxOnLaunch: !isCompactLayout
                    )
                }
            )
        }
        .alert(
            "Link Error",
            item: $takeNoteVM.linkToNoteErrorMessage
        ) {
            _ in Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "Empty Trash?",
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
        } message: {
            Text("This action cannot be undone.")
        }
        .focusedSceneValue(\.modelContext, modelContext)
        .focusedSceneValue(\.chatEnabled, chatEnabled)
        .focusedSceneValue(\.mainWindowActions, mainWindowActions)
        .alert(
            "Something went wrong",
            item: $takeNoteVM.errorAlertMessage
        ) {
            _ in Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "Notes Found in Cut and Paste Buffer",
            isPresented: $notesInBufferMessagePresented
        ) {
            Button("OK", role: .cancel) {
                notesInBufferMessagePresented = false
            }
        } message: {
            if takeNoteVM.bufferNotesCount == 1 {
                Text(
                    "1 note will be returned to your Inbox.",
                    comment: "Message shown when one note is recovered from the cut and paste buffer."
                )
            } else {
                Text(
                    "\(takeNoteVM.bufferNotesCount, format: .number) notes will be returned to your Inbox.",
                    comment: "Message shown when multiple notes are recovered from the cut and paste buffer; the variable is the number of notes."
                )
            }
        }
        .alert(
            "Orphaned Notes Recovered",
            isPresented: $takeNoteVM.orphanRecoveryAlertVisible
        ) {
            Button("OK", action: { takeNoteVM.orphanRecoveryAlertVisible = false })
        } message: {
            Text(
                "Orphaned notes were found. These can be caused by sync problems or device crashes. Orphaned notes have been moved to a new \(takeNoteVM.orphanRecoveryFolderName) folder. No data was lost.",
                comment: "Recovery alert message; the variable is the name of the folder that received recovered notes."
            )
        }
        .onAppear(perform: {
            takeNoteVM.trashFolder = containers.first(where: { $0.isTrash })
            takeNoteVM.inboxFolder = containers.first(where: { $0.isInbox })
            takeNoteVM.bufferFolder = containers.first(where: { $0.isBuffer })

            takeNoteVM.folderInit(
                modelContext,
                selectInboxOnLaunch: !isCompactLayout
            )
            if !takeNoteVM.bufferIsEmpty {
                notesInBufferMessagePresented = true
                takeNoteVM.moveNotesFromBufferToInbox(modelContext)
            }

        })
        .onOpenURL(perform: { url in
            if url.host == "image" {
                Self.logger.info("Received image URL in onOpenURL — ignoring as in-process only")
                return
            }
            takeNoteVM.loadNoteFromURL(url, modelContext: modelContext)
        })
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let noteID = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let url = URL(string: "takenote://note/\(noteID)")
            else {
                return
            }
            takeNoteVM.loadNoteFromURL(url, modelContext: modelContext)
        }
    }

}

#Preview {
    MainWindow()
}
