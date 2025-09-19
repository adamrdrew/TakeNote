//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI

#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

struct MovePopoverContent: View {
    @Environment(TakeNoteVM.self) var takeNoteVM
    @State var selectedContainer: NoteContainer?

    var note: Note
    var onSelect: () -> Void

    var body: some View {
        List(selection: $selectedContainer) {
            Section(
                content: {
                    FolderList()
                },
                header: {
                    Text("Folders")
                }
            )
            .headerProminence(.increased)
            Section(
                content: {
                    TagList()
                },
                header: {
                    Text("Tags")
                }
            ).headerProminence(.increased)
        }
        .onChange(of: selectedContainer) { _, newValue in
            guard let container = newValue else { return }
            if container.isTag {
                note.tag = container
            } else {
                note.folder = container
            }
            takeNoteVM.selectedContainer = container
            onSelect()
        }
    }
}

struct NoteListEntry: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(TakeNoteVM.self) var takeNoteVM

    @Environment(\.noteDeleteRegistry) private var noteDeleteRegistry
    @Environment(\.noteCopyMarkdownLinkRegistry) private
        var noteCopyMarkdownLinkRegistry
    @Environment(\.noteRenameRegistry) private var noteRenameRegistry
    @Environment(\.noteStarToggleRegistry) private var noteStarToggleRegistry
    @Environment(\.noteOpenEditorWindowRegistry) private
        var noteOpenEditorWindowRegistry

    var note: Note
    @State private var inRenameMode: Bool = false
    @State private var inMoveToTrashMode: Bool = false
    @State private var inMoveToContainerMode: Bool = false
    @State private var newName: String = ""
    @State private var showExportDialog: Bool = false
    @State private var exportError: String? = nil
    @State private var showExportError: Bool = false
    @FocusState private var nameInputFocused: Bool

    private let verticalPadding: CGFloat = 8
    private let horizontalPadding: CGFloat = 12
    private let hSpacing: CGFloat = 8
    private let vSpacing: CGFloat = 6

    func copyMarkdownLink() {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(note.getMarkdownLink(), forType: .string)
        #endif
        #if os(iOS)
            let pasteboard = UIPasteboard.general
            pasteboard.string = note.getMarkdownLink()
        #endif
    }

    func openEditorWindow() {
        openWindow(
            id: "note-editor-window",
            value: NoteIDWrapper(id: note.persistentModelID)
        )
    }

    func moveToTrash() {
        takeNoteVM.moveNoteToTrash(note, modelContext: modelContext)
        noteDeleteRegistry.unregisterCommand(id: note.id)
        noteRenameRegistry.unregisterCommand(id: note.id)
    }

    func startRename() {
        inRenameMode = true
        newName = note.title
        nameInputFocused = true
    }

    func finishRename() {
        inRenameMode = false
        note.setTitle(newName)
        try? modelContext.save()
    }

    func noteStarToggle() {
        takeNoteVM.noteStarredToggle(note, modelContext: modelContext)
    }

    var iconColor: Color {
        if note == takeNoteVM.openNote {
            return .primary
        }
        return .takeNotePink
    }

    var TitleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: hSpacing) {
            if inRenameMode {
                TextField("New Note Name", text: $newName)
                    .focused($nameInputFocused)
                    .font(.headline.weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { finishRename() }
                    .onChange(of: nameInputFocused) { _, focused in
                        if !focused {
                            finishRename()
                        }
                    }
            } else {
                Label {
                    Text(note.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: "note.text")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(iconColor)
                }
                .labelStyle(.titleAndIcon)
            }

            if let noteLabel = note.tag {
                NoteLabelBadge(noteLabel: noteLabel)
                    .alignmentGuide(.firstTextBaseline) { d in
                        d[.firstTextBaseline]
                    }
            }

            Spacer(minLength: 0)
            #if os(macOS)
                Button("", systemImage: note.starred ? "star.fill" : "star") {
                    noteStarToggle()
                }
                .buttonStyle(.plain)
                .imageScale(.medium)
                .foregroundStyle(note.starred ? .yellow : .secondary)
                .help(note.starred ? "Unstar" : "Star")
            #else
                if note.starred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(.yellow))
                }

            #endif
        }
    }

    var MetadataRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(note.createdDate, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if takeNoteVM.selectedContainer?.isTag == true {
                Label {
                    Text(note.folder!.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "folder")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(iconColor)
                }

            }
        }
    }

    var SummaryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if note.aiSummaryIsGenerating {
                AIMessage(
                    message: "AI Summary Generating...",
                    font: .callout
                )
            } else {
                if !note.aiSummary.isEmpty {
                    Label {
                        Text(note.aiSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    } icon: {
                        Image(systemName: "apple.intelligence")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [
                                        .orange, .pink, .blue, .purple,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),

                            )
                    }
                } else {
                    Label {
                        Text(
                            note.content.replacingOccurrences(
                                of: "\n",
                                with: " "
                            )
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    } icon: {
                        Image(systemName: "text.magnifyingglass")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var DragRepresentation: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.0, style: .continuous)
                .frame(width: 24, height: 32)
                .foregroundColor(.white)
                .border(.gray, width: 1)
            VStack {
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundColor(.gray)
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundColor(.gray)
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundColor(.gray)
            }
        }
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        VStack(alignment: .leading, spacing: vSpacing) {
            TitleRow
                .allowsHitTesting(true)
            MetadataRow
                .allowsHitTesting(false)
            SummaryRow
                .allowsHitTesting(false)
        }
        // trailing = left swipe
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: { moveToTrash() }) {
                Label("Trash", systemImage: "trash")
            }
            Button(action: { noteStarToggle() }) {
                Label(
                    note.starred ? "Unstar" : "Star",
                    systemImage: note.starred ? "star.slash" : "star"
                )
            }
            .tint(.yellow)
        }
        #if os(iOS)
            // leading = right swipe
            .swipeActions(edge: .leading) {
                Button(action: { inMoveToContainerMode = true }) {
                    Label("Move", systemImage: "arrow.down.app")
                }
            }
            .popover(isPresented: $inMoveToContainerMode) {
                MovePopoverContent(
                    note: note,
                    onSelect: {
                        inMoveToContainerMode = false
                    }
                )
            }
        #endif
        .draggable(NoteIDWrapper(id: note.persistentModelID)) {
            DragRepresentation
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        // I had this in here but I'm not sure it is doing anything
        //.frame(maxWidth: .infinity, alignment: .leading)
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { openEditorWindow() }
        )
        .contextMenu {

            if takeNoteVM.selectedContainer?.isTrash == false {
                Button(
                    role: .destructive,
                    action: {
                        inMoveToTrashMode = true
                    }
                ) {
                    Label("Move to Trash", systemImage: "trash")
                }
                Button(action: {
                    startRename()
                }) {
                    Label("Rename", systemImage: "square.and.pencil")
                }
            }

            if takeNoteVM.selectedContainer?.isTrash == true
                || takeNoteVM.selectedContainer?.isTag == true
                || takeNoteVM.selectedContainer?.isStarred == true
            {
                Button(action: {
                    takeNoteVM.selectedContainer = note.folder
                }) {
                    Label(
                        "Go to Note Folder",
                        systemImage: "arrow.forward.folder"
                    )
                }
            }

            #if os(macOS)
                Button(
                    action: {
                        openEditorWindow()
                    }
                ) {
                    Label("Open Editor Window", systemImage: "macwindow")
                }
            #endif
            if !note.isEmpty {
                Button(
                    action: {
                        showExportDialog = true
                    }
                ) {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
            }

            Button(action: {
                #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(note.getURL(), forType: .string)
                #endif
                #if os(iOS)
                    let pasteboard = UIPasteboard.general
                    pasteboard.string = note.getURL()
                #endif
            }) {
                Label("Copy URL", systemImage: "link")
            }
            Button(action: {
                copyMarkdownLink()
            }) {
                Label("Copy Markdown Link", systemImage: "link")
            }
            if let noteLabel = note.tag {
                Button(
                    role: .destructive,
                    action: {
                        note.tag = nil
                        try? modelContext.save()
                    }
                ) {
                    Label(
                        "Remove tag: \(noteLabel.name)",
                        systemImage: "xmark"
                    )
                }
            }
        }
        .fileExporter(
            isPresented: $showExportDialog,
            document: TextFile(initialText: note.content),
            defaultFilename: "\(note.title).md"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                exportError = error.localizedDescription
                showExportError = true
            }
        }
        .onAppear {
            noteDeleteRegistry.registerCommand(
                id: note.persistentModelID,
                command: moveToTrash
            )
            noteRenameRegistry.registerCommand(
                id: note.persistentModelID,
                command: startRename
            )
            noteStarToggleRegistry.registerCommand(
                id: note.persistentModelID,
                command: noteStarToggle
            )
            noteOpenEditorWindowRegistry.registerCommand(
                id: note.persistentModelID,
                command: openEditorWindow
            )
            noteCopyMarkdownLinkRegistry.registerCommand(
                id: note.persistentModelID,
                command: copyMarkdownLink
            )
        }
        .onDisappear {
            noteDeleteRegistry.unregisterCommand(id: note.persistentModelID)
            noteRenameRegistry.unregisterCommand(id: note.persistentModelID)
            noteStarToggleRegistry.unregisterCommand(id: note.persistentModelID)
            noteCopyMarkdownLinkRegistry.unregisterCommand(
                id: note.persistentModelID
            )
            noteOpenEditorWindowRegistry.unregisterCommand(
                id: note.persistentModelID
            )
        }
        .alert(
            "Something went wrong exporting your file: \(String(describing: exportError ?? "Unknown Error"))",
            isPresented: $showExportError
        ) {
            Button("OK", role: .cancel) {
                showExportError = false
            }
        }
        .alert(
            "Are you sure you want to move \(note.title) to the trash?",
            isPresented: $inMoveToTrashMode
        ) {
            Button("Move to Trash", role: .destructive) {
                moveToTrash()
            }
            Button("Cancel", role: .cancel) {
                inMoveToTrashMode = false
            }
        }
    }
}
