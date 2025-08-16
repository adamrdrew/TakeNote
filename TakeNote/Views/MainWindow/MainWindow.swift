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
    let languageModel = SystemLanguageModel.default

    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    @Query var notes: [Note]

    var inboxFolder: NoteContainer? {
        folders.first { $0.isInbox }
    }
    var trashFolder: NoteContainer? {
        folders.first { $0.isTrash }
    }

    @State var selectedContainer: NoteContainer?
    @State var selectedNotes = Set<Note>()
    @State var openNote: Note?
    @State var emptyTrashAlertIsPresented: Bool = false
    @State var linkToNoteErrorIsPresented: Bool = false
    @State var linkToNoteErrorMessage: String = ""
    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var errorAlertMessage: String = ""
    @State var errorAlertIsVisible: Bool = false
    @State var showMultiNoteView: Bool = false

    var multipleNotesSelected: Bool {
        return selectedNotes.count > 1
    }

    func onNoteSelect(_ note: Note) {
        openNote = note
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedContainer) {
                Section(
                    isExpanded: $folderSectionExpanded,
                    content: {
                        FolderList(
                            selectedContainer: $selectedContainer,
                            onDelete: folderDelete,
                            onEmptyTrash: emptyTrash
                        )

                    },
                    header: {
                        Text("Folders")
                    }
                )
                .headerProminence(.increased)

                if tagsExist {
                    Section(
                        isExpanded: $tagSectionExpanded,
                        content: {
                            TagList(
                                onDelete: onTagDelete
                            )
                        },
                        header: {
                            Text("Tags")
                        }
                    ).headerProminence(.increased)

                }
            }

            .listStyle(.sidebar)
            .toolbar {
                Button(action: addFolder) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .help("Add Folder")
                AddTagButton(action: addTag)
            }

        } content: {
            NoteList(
                selectedContainer: $selectedContainer,
                selectedNotes: $selectedNotes,
                onTrash: moveNoteToTrash,
                onSelect: onNoteSelect
            ).toolbar {
                if canAddNote {
                    Button(action: addNote) {
                        Image(systemName: "note.text.badge.plus")
                    }
                    .help("Add Note")
                }
                if aiIsAvailable && notes.count > 0 {
                    Button(action: openChatWindow) {
                        Label("Chat", systemImage: "message")
                    }
                    .help("AI Chat")
                }
                if canEmptyTrash {
                    Button(action: showEmptyTrashAlert) {
                        Label("Empty Trash", systemImage: "trash.slash")
                    }
                    .help("Empty Trash")
                }

            }

        } detail: {
            if showMultiNoteView {
                MultiNoteViewer(notes: $selectedNotes)
                    .transition(.opacity)

            } else {
                NoteEditor(openNote: $openNote)
                    .transition(.opacity)
            }

        }
        .onChange(of: multipleNotesSelected) { _, newValue in
            withAnimation {
                showMultiNoteView = newValue
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300)
        .navigationTitle(navigationTitle)
        .alert(
            "Link Error: \(linkToNoteErrorMessage)",
            isPresented: $linkToNoteErrorIsPresented
        ) {
            Button("OK", action: { linkToNoteErrorIsPresented = false })
        }
        .alert(
            "Are you sure you want to empty the trash? This action cannot be undone.",
            isPresented: $emptyTrashAlertIsPresented
        ) {
            Button("Empty Trash", role: .destructive, action: emptyTrash)
        }
        .alert(
            "Something went wrong: \(errorAlertMessage)",
            isPresented: $errorAlertIsVisible
        ) {
            Button("OK", action: { errorAlertIsVisible = false })
        }
        .onAppear(perform: dataInit)
        .onOpenURL(perform: loadNoteFromURL)

    }

}

#Preview {
    MainWindow()
}
