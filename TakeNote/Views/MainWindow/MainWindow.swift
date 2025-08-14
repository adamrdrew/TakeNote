//
//  MainWindow.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import FoundationModels
import SwiftData
import SwiftUI

struct MainWindow: View {
    static let inboxFolderName = "Inbox"
    static let trashFolderName = "Trash"
    let model = SystemLanguageModel.default
    @Environment(\.modelContext) internal var modelContext
    @Environment(\.openWindow) internal var openWindow
    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isInbox
        }
    ) var inboxFolders: [NoteContainer]
    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTrash
        }
    ) var trashFolders: [NoteContainer]
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    @State internal var selectedFolder: NoteContainer?
    @State internal var selectedNote: Note?
    @State internal var emptyTrashAlertIsVisible: Bool = false

    @State internal var linkToNoteErrorIsVisible: Bool = false
    @State internal var linkToNoteErrorMessage: String = ""

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedFolder) {
                Section(
                    isExpanded: $folderSectionExpanded,
                    content: {
                        FolderList(
                            selectedFolder: $selectedFolder,
                            onDelete: folderDelete,
                            onEmptyTrash: emptyTrash
                        )
                    },
                    header: {
                        Text("Folders")
                    }
                )
                .headerProminence(.increased)

                Section(
                    isExpanded: $tagSectionExpanded,
                    content: {
                        TagList(
                            selectedFolder: $selectedFolder,
                            onDelete: onTagDelete
                        )
                    },
                    header: {
                        Text("Tags")
                    }
                ).headerProminence(.increased)
            }
            .listStyle(.sidebar)
            .toolbar {
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                AddTagButton(action: addTag)
            }

        } content: {
            NoteList(
                selectedFolder: $selectedFolder,
                selectedNote: $selectedNote,
                onTrash: moveNoteToTrash
            ).toolbar {
                if aiIsAvailable {
                    Button(action: openChatWindow) {
                        Label("Chat", systemImage: "message")
                    }
                }
                if canEmptyTrash {
                    Button(action: showEmptyTrashAlert) {
                        Label("Empty Trash", systemImage: "trash.slash")
                    }
                }
                if canAddNote {
                    Button(action: addNote) {
                        Image(systemName: "note.text.badge.plus")
                    }
                }
            }
        } detail: {
            NoteEditor(selectedNote: $selectedNote)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300)
        .navigationTitle(navigationTitle)

        .alert(
            "Link Error: \(linkToNoteErrorMessage)",
            isPresented: $linkToNoteErrorIsVisible
        ) {
            Button("OK", action: { linkToNoteErrorIsVisible = false })
        }
        .alert(
            "Are you sure you want to empty the trash? This action cannot be undone.",
            isPresented: $emptyTrashAlertIsVisible
        ) {
            Button("Empty Trash", role: .destructive, action: emptyTrash)
            Button("Cancel", action: { emptyTrashAlertIsVisible = false })
        }
        .onAppear(perform: dataInit)
        .onOpenURL(perform: loadNoteFromURL)
    }
}

#Preview {
    MainWindow()
}
