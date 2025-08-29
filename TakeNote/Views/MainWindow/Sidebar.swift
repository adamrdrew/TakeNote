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

 Menubar commands sit outside of the view hierarchy. This makes accessing state and functionality
 within the View hierarchy challenging. The correct way to do this is with FocusedValues. When a
 View has focus you can have it pop data into the FocusedValues that the Menubar Commands can read.

 There's a problem though. SwiftUI Lists get focus, but their child list items do not. In TakeNote
 the functionality and UI for rename and delete happen in the list items. This made implementing rename
 and delete challenging. I could find no information on how SwiftUI developers for macOS are supposed to
 address this issue, so I came up with the following solution.

 I created a class called CommandRegistry. Instances of CommandRegistry can map SwiftData PersistantIdentfiers
 to functions of type () -> Void. This is done via the CommandRegistry.registerCommand(id:) method. The registered
 commands can then be run via the CommandRegistry.runCommand(id:) method.

 Sidebar creates two CommandRegistry instanes: containerDeleteRegistry and containerRenameRegistry. These
 CommandRegistries are then added to the Environment with the \.containerDeleteRegistry and \.containerRenameRegistry
 environment keys. The List items are able to access the registries via the environment. On appear the
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

 I think this is an utterly insane way to do this and feel SwiftUI should have some way to accomplish this natively
 or that there be some pattern devs can use to do this that doesn't require so much boilerplate and abstraction.
 However, I can find no such way. I can find no docuemntation from Apple on how this should be done. Nor can I find
 so much as a single article or blog post online where anyone deals with this same problem. Though I know others must
 have run into this.
 */

/// FocusedValues are set by the List when it has focus and used by the Menubar Edit Commands
extension FocusedValues {
    @Entry var containerDeleteRegistry: CommandRegistry?
    @Entry var containerRenameRegistry: CommandRegistry?
    @Entry var selectedNoteContainer: NoteContainer?
    @Entry var tagSetColorRegistry: CommandRegistry?
}

/// Allow our command registries for delete and rename commands to be accessed from the environment
/// by keys, rather than by types. This allows us to have multiple CommandRegistry instances in the environment
private struct ContainerDeleteRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct ContainerRenameRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
private struct TagSetColorRegistryKey: EnvironmentKey {
    static let defaultValue: CommandRegistry = CommandRegistry()
}
extension EnvironmentValues {
    var containerDeleteRegistry: CommandRegistry {
        get { self[ContainerDeleteRegistryKey.self] }
        set { self[ContainerDeleteRegistryKey.self] = newValue }
    }
    var containerRenameRegistry: CommandRegistry {
        get { self[ContainerRenameRegistryKey.self] }
        set { self[ContainerRenameRegistryKey.self] = newValue }
    }
    var tagSetColorRegistry: CommandRegistry {
        get { self[TagSetColorRegistryKey.self] }
        set { self[TagSetColorRegistryKey.self] = newValue }
    }
}

struct Sidebar: View {
    @Environment(SearchIndexService.self) var search
    @Environment(TakeNoteVM.self) var takeNoteVM
    @Environment(\.modelContext) var modelContext

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in
            !folder.isTag && !folder.isTrash && !folder.isInbox
                && !folder.isBuffer
        }
    ) var folders: [NoteContainer]

    @Query(
        filter: #Predicate<NoteContainer> { folder in
            folder.isTrash || folder.isInbox
        }
    ) var systemFolders: [NoteContainer]

    @State var folderSectionExpanded: Bool = true
    @State var tagSectionExpanded: Bool = true
    @State var showImportError: Bool = false
    @State var importErrorMessage: String = ""

    @State var containerDeleteRegistry: CommandRegistry = CommandRegistry()
    @State var containerRenameRegistry: CommandRegistry = CommandRegistry()
    @State var tagSetColorRegistry: CommandRegistry = CommandRegistry()

    var tagsExist: Bool {
        return tags.isEmpty == false
    }

    var body: some View {
        @Bindable var takeNoteVMBinding = takeNoteVM
        List(selection: $takeNoteVMBinding.selectedContainer) {
            Section(
                content: {
                    ForEach(systemFolders.sorted(by: { $0.name < $1.name}), id: \.self) { folder in
                        FolderListEntry(
                            folder: folder
                        )
                    }
                },
                header: {
                    Text("TakeNote")
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
        /// Add the command registries to the environment so that the list entries can access them
        .environment(\.containerDeleteRegistry, containerDeleteRegistry)
        .environment(\.containerRenameRegistry, containerRenameRegistry)
        .environment(\.tagSetColorRegistry, tagSetColorRegistry)
        /// Make the command registries the focused values for this list so that the menubar commands can access them
        .focusedValue(\.containerDeleteRegistry, containerDeleteRegistry)
        .focusedValue(\.containerRenameRegistry, containerRenameRegistry)
        .focusedValue(\.tagSetColorRegistry, tagSetColorRegistry)
        /// Make the selected container available to the menubar commands so we can use its ID to resolve the correct commands in the
        /// command registries
        .focusedValue(
            \.selectedNoteContainer,
            takeNoteVMBinding.selectedContainer
        )
        .dropDestination(for: URL.self, isEnabled: true) { items, location in
            let importResult = folderImport(
                items: items,
                modelContext: modelContext,
                searchIndex: search
            )
            importErrorMessage = importResult.toString()
            showImportError = importResult.errorsEncountered
        }
        .alert(importErrorMessage, isPresented: $showImportError) {
            Button("OK") {
                showImportError.toggle()
            }
        }
        .listStyle(.sidebar)
        /*
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    takeNoteVM.addFolder(modelContext)
                }) {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
                .help("Add Folder")
                AddTagButton(action: {
                    takeNoteVM.addTag(modelContext: modelContext)
                })
            }
        
        }*/
    }
}
