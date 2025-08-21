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
    
    @Environment(TakeNoteVM.self) var takeNoteVM
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

    @State var selectedNotes = Set<Note>()
    @State var emptyTrashAlertIsPresented: Bool = false
    @State var linkToNoteErrorIsPresented: Bool = false
    @State var linkToNoteErrorMessage: String = ""
    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var errorAlertMessage: String = ""
    @State var errorAlertIsVisible: Bool = false
    @State var showMultiNoteView: Bool = false


    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        NavigationSplitView {
            // TODO: Figure out what we can pull out of MainWindow and push into Sidebar so we aren't
            // passing so much shit into it
            Sidebar(
                tagsExist: tagsExist,
                onMoveToFolder: onMoveToFolder,
                onFolderDelete: folderDelete,
                onTagDelete: onTagDelete,
                onEmptyTrash: emptyTrash,
                onAddFolder: addFolder,
                onAddTag: addTag
            )

        } content: {
            NoteList(
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
                NoteEditor(
                    openNote: $takeNoteVM.openNote,
                )
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
