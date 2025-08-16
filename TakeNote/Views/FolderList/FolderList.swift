//
//  FolderList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct FolderList: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedContainer: NoteContainer?
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]
    var onMoveToFolder: () -> Void = {}
    
    var onDelete: ((_ deletedFolder: NoteContainer) -> Void) = {
        deletedFolder in
    }
    var onEmptyTrash: (() -> Void) = {}

    var body: some View {
        ForEach(folders, id: \.self) { folder in
            FolderListEntry(
                folder: folder,
                onMoveToFolder: onMoveToFolder,
                onDelete: onDelete,
                onEmptyTrash: onEmptyTrash
            )            
        }
    }
}
