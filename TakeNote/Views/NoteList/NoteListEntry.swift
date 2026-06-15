//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif
#if os(iOS)
    import UIKit
#endif

struct MovePopoverContent: View {
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @State private var selectedContainer: NoteContainer?

    let note: Note
    let onSelect: () -> Void

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
                note.setTag(container)
            } else {
                note.setFolder(container)
            }
            takeNoteVM.selectedContainer = container
            onSelect()
        }
    }
}

struct NoteListEntry: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(TakeNoteVM.self) private var takeNoteVM

    @Environment(\.noteDeleteRegistry) private var noteDeleteRegistry
    @Environment(\.noteCopyMarkdownLinkRegistry) private
        var noteCopyMarkdownLinkRegistry
    @Environment(\.noteRenameRegistry) private var noteRenameRegistry
    @Environment(\.noteStarToggleRegistry) private var noteStarToggleRegistry
    @Environment(\.noteOpenEditorWindowRegistry) private
        var noteOpenEditorWindowRegistry
    @Environment(SearchIndexService.self) private var search

    let note: Note
    @State private var inRenameMode: Bool = false
    @State private var notePendingTrash: Note?
    @State private var inMoveToContainerMode: Bool = false
    @State private var newName: String = ""
    @State private var showExportDialog: Bool = false
    @State private var exportError: String? = nil
    @State private var summaryTask: Task<Void, Never>?
    @FocusState private var nameInputFocused: Bool

    private let verticalPadding: CGFloat = 8
    private let horizontalPadding: CGFloat = 12
    private let hSpacing: CGFloat = 8
    private let vSpacing: CGFloat = 6

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    private func copyMarkdownLink() {
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

    private func openEditorWindow() {
        openWindow(
            id: "note-editor-window",
            value: NoteIDWrapper(id: note.persistentModelID)
        )
    }

    private func unregisterNoteCommands(for note: Note) {
        noteDeleteRegistry?.unregisterCommand(id: note.persistentModelID)
        noteRenameRegistry?.unregisterCommand(id: note.persistentModelID)
        noteStarToggleRegistry?.unregisterCommand(id: note.persistentModelID)
        noteCopyMarkdownLinkRegistry?.unregisterCommand(id: note.persistentModelID)
        noteOpenEditorWindowRegistry?.unregisterCommand(id: note.persistentModelID)
    }

    private func moveToTrash() {
        if takeNoteVM.selectedNotes.isEmpty == false {
            moveSelectedNotesToTrash()
            return
        }
        takeNoteVM.moveNoteToTrash(note, modelContext: modelContext)
        search.deleteFromIndex(noteID: note.uuid)
        unregisterNoteCommands(for: note)
        if takeNoteVM.openNote == note {
            takeNoteVM.openNote = nil
        }
    }

    private func moveSelectedNotesToTrash() {
        for sn in takeNoteVM.selectedNotes {
            takeNoteVM.moveNoteToTrash(sn, modelContext: modelContext)
            search.deleteFromIndex(noteID: sn.uuid)
            unregisterNoteCommands(for: sn)
            if sn.persistentModelID == takeNoteVM.openNote?.persistentModelID {
                takeNoteVM.openNote = nil
            }
        }
    }

    private func startRename() {
        inRenameMode = true
        newName = note.title
        nameInputFocused = true
    }

    private func finishRename() {
        inRenameMode = false
        note.setTitle(newName)
        do {
            try modelContext.save()
            search.reindex(note: note)
        } catch {
            takeNoteVM.presentError(error.localizedDescription)
        }
    }

    private func noteStarToggle() {
        takeNoteVM.noteStarredToggle(note, modelContext: modelContext)
    }

    private func regenerateSummary() {
        summaryTask?.cancel()
        note.contentHash = ""
        summaryTask = Task {
            await note.generateSummary()
        }
    }

    private func archiveNote() {
        takeNoteVM.moveNoteToArchive(note, modelContext: modelContext)
        search.deleteFromIndex(noteID: note.uuid)
    }

    private var isOpenNote: Bool {
        #if os(iOS)
            if isCompactLayout {
                return false
            }
        #endif
        return note == takeNoteVM.openNote
    }

    private var iconColor: Color {
        #if os(iOS)
            if isCompactLayout {
                return note.folder?.getColor() ?? .takeNotePink
            }
        #endif
        if isOpenNote {
            return .primary
        }
        return note.folder?.getColor() ?? .takeNotePink
    }

    var body: some View {
        @Bindable var takeNoteVM = takeNoteVM
        VStack(alignment: .leading, spacing: vSpacing) {
            NoteListEntryTitleRow(
                title: note.title,
                isStarred: note.starred,
                iconColor: iconColor,
                hSpacing: hSpacing,
                inRenameMode: inRenameMode,
                newName: $newName,
                nameInputFocused: $nameInputFocused,
                finishRename: finishRename,
                toggleStar: noteStarToggle
            )
            NoteListEntryMetadataRow(
                createdDate: note.createdDate,
                folderName: note.folder?.name ?? "Folder",
                folderSymbol: note.folder?.symbol ?? "folder",
                tagName: note.tag?.name,
                tagColor: note.tag?.getColor(),
                iconColor: iconColor,
                showsFolder: takeNoteVM.selectedContainer?.isTag == true
                    || takeNoteVM.selectedContainer?.isStarred == true
                    || takeNoteVM.selectedContainer?.isAllNotes == true,
                isOpenNote: isOpenNote
            )
                .allowsHitTesting(false)
            NoteListEntrySummaryRow(
                content: note.content,
                aiSummary: note.aiSummary,
                aiSummaryIsGenerating: note.aiSummaryIsGenerating,
                isOpenNote: isOpenNote
            )
                .allowsHitTesting(false)
        }
        // trailing = left swipe
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if note.folder?.isTrash != true {
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
        }
        // leading = right swipe
        .swipeActions(edge: .leading) {
            if note.folder?.isArchive != true && note.folder?.isTrash != true {
                Button(action: { archiveNote() }) {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.blue)
                #if os(iOS)
                Button(action: { inMoveToContainerMode = true }) {
                    Label("Move", systemImage: "arrow.down.app")
                }
                #endif
            }
        }
        #if os(iOS)
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
            NoteListEntryDragPreview()
        }
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { openEditorWindow() }
        )
        .contextMenu {

            if note.folder?.isArchive != true && note.folder?.isTrash != true {
                Button(action: { archiveNote() }) {
                    Label("Move to Archive", systemImage: "archivebox")
                }
            }

            if takeNoteVM.selectedContainer?.isTrash == false {
                Button(
                    role: .destructive,
                    action: {
                        notePendingTrash = note
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

            if takeNoteVM.selectedContainer?.isTag == true
                || takeNoteVM.selectedContainer?.isStarred == true
                || takeNoteVM.selectedContainer?.isAllNotes == true
            {
                Button(action: {
                    if let f = note.folder { takeNoteVM.selectedContainer = f }
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
            if takeNoteVM.aiIsAvailable {
                Button(action: {
                    regenerateSummary()
                }) {
                    Label(
                        "Regenerate Summary",
                        systemImage: "apple.intelligence"
                    )
                }
            }
            if let noteLabel = note.tag {
                Button(
                    role: .destructive,
                    action: {
                        note.tag = nil
                        do {
                            try modelContext.save()
                        } catch {
                            takeNoteVM.presentError(error.localizedDescription)
                        }
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
            contentType: .plainText,
            defaultFilename: "\(note.title).md"
        ) { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                exportError = error.localizedDescription
            }
        }
        .onAppear {
            noteDeleteRegistry?.registerCommand(
                id: note.persistentModelID,
                command: moveToTrash
            )
            noteRenameRegistry?.registerCommand(
                id: note.persistentModelID,
                command: startRename
            )
            noteStarToggleRegistry?.registerCommand(
                id: note.persistentModelID,
                command: noteStarToggle
            )
            noteOpenEditorWindowRegistry?.registerCommand(
                id: note.persistentModelID,
                command: openEditorWindow
            )
            noteCopyMarkdownLinkRegistry?.registerCommand(
                id: note.persistentModelID,
                command: copyMarkdownLink
            )
        }
        .onDisappear {
            unregisterNoteCommands(for: note)
            summaryTask?.cancel()
            summaryTask = nil
        }
        .alert(
            "Export Failed",
            item: $exportError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .alert(
            "Move Note to Trash?",
            item: $notePendingTrash
        ) { _ in
            Button("Move to Trash", role: .destructive) { moveToTrash() }
            Button("Cancel", role: .cancel) {}
        } message: { note in
            Text(
                "Are you sure you want to move \(note.title) to the trash?",
                comment: "Confirmation message before moving a note to trash; the variable is the note title."
            )
        }
    }
}

private struct NoteListEntryTitleRow: View {
    let title: String
    let isStarred: Bool
    let iconColor: Color
    let hSpacing: CGFloat
    let inRenameMode: Bool
    @Binding var newName: String
    let nameInputFocused: FocusState<Bool>.Binding
    let finishRename: () -> Void
    let toggleStar: () -> Void

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: hSpacing) {
            if inRenameMode {
                TextField("New Note Name", text: $newName)
                    .focused(nameInputFocused)
                    .font(.headline.weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(finishRename)
                    .onChange(of: nameInputFocused.wrappedValue) { _, focused in
                        if !focused { finishRename() }
                    }
            } else {
                Label {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: "note.text")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(iconColor)
                }
                .labelStyle(.titleAndIcon)
                .allowsHitTesting(false)
            }

            Spacer(minLength: 0)

            #if os(macOS)
                Button(action: toggleStar) {
                    Image(systemName: isStarred ? "star.fill" : "star")
                        .imageScale(.medium)
                        .foregroundStyle(isStarred ? .yellow : .secondary)
                        .padding(.zero)
                }
                .buttonStyle(.plain)
                .help(isStarred ? "Unstar" : "Star")
            #else
                if isStarred {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(.yellow))
                        .padding(.zero)
                }
            #endif
        }
    }
}

private struct NoteListEntryMetadataRow: View {
    let createdDate: Date
    let folderName: String
    let folderSymbol: String
    let tagName: String?
    let tagColor: Color?
    let iconColor: Color
    let showsFolder: Bool
    let isOpenNote: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(createdDate, style: .date)
                .font(.subheadline)
                .foregroundStyle(isOpenNote ? .primary : .secondary)

            Spacer(minLength: 0)

            NoteListEntryMetadataTrailingLabel(
                folderName: folderName,
                folderSymbol: folderSymbol,
                tagName: tagName,
                tagColor: tagColor,
                iconColor: iconColor,
                showsFolder: showsFolder,
                isOpenNote: isOpenNote
            )
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct NoteListEntryMetadataTrailingLabel: View {
    let folderName: String
    let folderSymbol: String
    let tagName: String?
    let tagColor: Color?
    let iconColor: Color
    let showsFolder: Bool
    let isOpenNote: Bool

    var body: some View {
        if showsFolder {
            HStack(spacing: 3) {
                Text(folderName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.subheadline)
                    .foregroundStyle(isOpenNote ? .primary : .secondary)

                Image(systemName: folderSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconColor)
                    .imageScale(.medium)
            }
        } else if let tagName, let tagColor {
            HStack(spacing: 3) {
                Text(tagName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.subheadline)
                    .foregroundStyle(isOpenNote ? .primary : .secondary)

                Image(systemName: "tag.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tagColor)
                    .imageScale(.medium)
            }
        }
    }
}

private struct NoteListEntrySummaryRow: View {
    let content: String
    let aiSummary: String
    let aiSummaryIsGenerating: Bool
    let isOpenNote: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if aiSummaryIsGenerating {
                AIMessage(
                    message: "AI Summary Generating...",
                    font: .callout
                )
            } else if !aiSummary.isEmpty {
                Label {
                    Text(aiSummary)
                        .font(.callout)
                        .foregroundStyle(isOpenNote ? .primary : .secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: "apple.intelligence")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(summaryIconStyle)
                }
            } else {
                Label {
                    Text(content.replacingOccurrences(of: "\n", with: " "))
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

    private var summaryIconStyle: LinearGradient {
        if isOpenNote {
            return LinearGradient(
                colors: [.primary, .primary],
                startPoint: .leading,
                endPoint: .trailing
            )
        }

        return LinearGradient(
            colors: [.orange, .pink, .blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct NoteListEntryDragPreview: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.0, style: .continuous)
                .frame(width: 24, height: 32)
                .foregroundStyle(.white)
                .border(.gray, width: 1)
            VStack {
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundStyle(.gray)
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundStyle(.gray)
                Rectangle()
                    .frame(width: 12, height: 2)
                    .foregroundStyle(.gray)
            }
        }
    }
}
