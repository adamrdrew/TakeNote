//
//  Sidebar.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftData
import SwiftUI

/*
 How delete and rename commands work with the List entries, and why:

 Menu bar commands sit outside this view hierarchy, so they receive the current
 list context through FocusedValues. SwiftUI Lists receive focus, but row views
 do not, while TakeNote's rename and delete actions live at the row level.

 CommandRegistry maps SwiftData PersistentIdentifiers to row-local closures.
 Rows register their actions on appear and unregister on disappear.

 Sidebar creates CommandRegistry instances for container delete, container rename, and tag color actions.
 These registries are added to the environment so list items can access them. On appear the
 list items register their delete and rename methods via their container IDs to the registries. On disappear
 they unregister them.

 Sidebar also takes these same CommandRegistry instances and makes them the FocusedValues, so when the List
 has focus the CommandRegistry instances for delete and rename are available to the Menubar EditCommands. The
 EditCommands can then see that the FocusedValues for containerDeleteRegistry and containerRenameRegistry are
 non nil making them available for use.

 The final part of this is that the List also adds the selected container to the FocusedValues. When you put it
 all together it means that when the List has focus the Menubar edit commands see that the selected container and
 the registries are non nil which lights up the Rename and Delete menubar commands as available, and then they are
 able to run the commands at the List item level by using the ID of the selected container to resolve the correct list
 item methods by way of the CommandRegistry instances.
 */

private func systemFolderSortOrder(_ folder: NoteContainer) -> Int {
    if folder.isInbox { return 0 }
    if folder.isStarred { return 1 }
    if folder.isAllNotes { return 2 }
    if folder.isTrash { return 3 }
    if folder.isArchive { return 4 }
    return 5
}

struct Sidebar: View {
    @Environment(SearchIndexService.self) private var search
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) private var tags: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in
            !folder.isTag && !folder.isTrash && !folder.isInbox
                && !folder.isBuffer && !folder.isStarred && !folder.isAllNotes && !folder.isArchive
        }
    ) private var folders: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in
            folder.isTrash || folder.isInbox || folder.isStarred || folder.isAllNotes || folder.isArchive
        }
    ) private var systemFolders: [NoteContainer]

    @State private var folderSectionExpanded: Bool = true
    @State private var tagSectionExpanded: Bool = true
    @State private var importErrorMessage: String?
    @State private var importTask: Task<Void, Never>?
    @State private var importTaskToken: UUID?

    @State private var containerDeleteRegistry: CommandRegistry = CommandRegistry()
    @State private var containerRenameRegistry: CommandRegistry = CommandRegistry()
    @State private var tagSetColorRegistry: CommandRegistry = CommandRegistry()

    private var tagsExist: Bool {
        !tags.isEmpty
    }

    private var sortedSystemFolders: [NoteContainer] {
        systemFolders.sorted(by: { systemFolderSortOrder($0) < systemFolderSortOrder($1) })
    }

    private func importDroppedFolders(_ items: [URL]) {
        importTask?.cancel()
        let token = UUID()
        importTaskToken = token
        importTask = Task { @MainActor in
            defer {
                if importTaskToken == token {
                    importTask = nil
                    importTaskToken = nil
                }
            }

            let outcome = folderImport(
                items: items,
                modelContext: modelContext,
                searchIndex: search
            )
            guard !Task.isCancelled else { return }
            importErrorMessage = outcome.result.errorsEncountered
                ? outcome.result.toString()
                : nil
            await generateImportedNoteSummaries(for: outcome.importedNotes)
        }
    }

    private func cancelImport() {
        importTask?.cancel()
        importTask = nil
        importTaskToken = nil
    }

    var body: some View {
        @Bindable var takeNoteVMBinding = takeNoteVM
        List(selection: $takeNoteVMBinding.selectedContainer) {
            Section(
                content: {
                    ForEach(sortedSystemFolders) { folder in
                        FolderListEntry(
                            folder: folder
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .tag(folder)
                    }
                }
            )

            if folders.isEmpty == false {
                Section(
                    isExpanded: $folderSectionExpanded,
                    content: {
                        FolderList()
                    },
                    header: {
                        Text("Folders")
                    }
                )
                .headerProminence(.increased)
            }

            if tagsExist {
                Section(
                    isExpanded: $tagSectionExpanded,
                    content: {
                        TagList()
                    },
                    header: {
                        Text("Tags")
                    }
                ).headerProminence(.increased)

            }
        }
        // Add the command registries to the environment so list entries can access them.
        .environment(\.containerDeleteRegistry, containerDeleteRegistry)
        .environment(\.containerRenameRegistry, containerRenameRegistry)
        .environment(\.tagSetColorRegistry, tagSetColorRegistry)
        // Expose the same registries to menu commands via focused values.
        .focusedValue(\.containerDeleteRegistry, containerDeleteRegistry)
        .focusedValue(\.containerRenameRegistry, containerRenameRegistry)
        .focusedValue(\.tagSetColorRegistry, tagSetColorRegistry)
        // Menu commands use the selected container's ID to resolve registered commands.
        .focusedValue(
            \.selectedNoteContainer,
            takeNoteVM.selectedContainer
        )
        .dropDestination(for: URL.self, isEnabled: true) { items, _ in
            importDroppedFolders(items)
        }
        .alert("Import Failed", item: $importErrorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .listStyle(.sidebar)
        .onDisappear {
            cancelImport()
        }
    }
}
