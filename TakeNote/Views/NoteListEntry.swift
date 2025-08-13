//
//  NoteListEntry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/5/25.
//

import AppKit
import SwiftData
import SwiftUI

struct NoteListEntry: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    var note: Note
    var selectedFolder: NoteContainer?
    var onTrash: ((_ deletedNote: Note) -> Void) = { Note in }
    @State private var inRenameMode: Bool = false
    @State private var inMoveToTrashMode: Bool = false
    @State private var newName: String = ""
    @State private var showExportDialog : Bool = false
    @FocusState private var nameInputFocused: Bool
    

    private let verticalPadding: CGFloat = 8
    private let horizontalPadding: CGFloat = 12
    private let hSpacing: CGFloat = 8
    private let vSpacing: CGFloat = 6

    func openEditorWindow() {
        openWindow(
            id: "note-editor-window",
            value: NoteIDWrapper(id: note.persistentModelID)
        )
    }

    func moveToTrash() {
        onTrash(note)
    }

    func startRename() {
        inRenameMode = true
        newName = note.title
        nameInputFocused = true
    }

    func finishRename() {
        inRenameMode = false
        note.title = newName
        try? modelContext.save()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: vSpacing) {
            // Title row
            HStack(alignment: .firstTextBaseline, spacing: hSpacing) {
                if inRenameMode {
                    TextField("New Note Name", text: $newName)
                        .focused($nameInputFocused)
                        .font(.headline.weight(.semibold))
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { finishRename() }
                } else {
                    Label {
                        Text(note.title)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } icon: {
                        Image(systemName: "note.text")
                            .symbolRenderingMode(.hierarchical)
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

                Button("", systemImage: note.starred ? "star.fill" : "star") {
                    note.starred.toggle()
                    try? modelContext.save()
                }
                .buttonStyle(.plain)
                .imageScale(.medium)
                .foregroundStyle(note.starred ? .yellow : .secondary)
                .help(note.starred ? "Unstar" : "Star")
            }

            // Metadata row
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(note.createdDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                if selectedFolder?.isTag == true {
                    Label {
                        Text(note.folder.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } icon: {
                        Image(systemName: "folder")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

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
                                colors: [.blue, .orange, .purple],
                                startPoint: .top,
                                endPoint: .bottomTrailing
                            ),

                        )
                }
            }

            if note.aiSummaryIsGenerating {
                Label {
                    Text("AI Summary Generating...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                } icon: {
                    Image(systemName: "apple.intelligence")
                        .symbolRenderingMode(.hierarchical)

                }
                .symbolEffect(.bounce.down)
                .symbolEffect(.rotate)
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue, .orange, .purple],
                        startPoint: .top,
                        endPoint: .bottomTrailing
                    ),

                )

            }
        }
        .draggable(NoteIDWrapper(id: note.persistentModelID))
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { openEditorWindow() }
        )
        .contextMenu {

            if selectedFolder?.isTrash == false {
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
            Button(
                action: {
                    openEditorWindow()
                }
            ) {
                Label("Open Editor Window", systemImage: "macwindow")
            }
            if !note.isEmpty {
                Button(
                    action: {
                        showExportDialog = true
                    }
                ){
                    Label("Export", systemImage: "square.and.arrow.down")
                }
            }

            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(note.getURL(), forType: .string)
            }) {
                Label("Copy link", systemImage: "link")
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
            print("File saved")
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
