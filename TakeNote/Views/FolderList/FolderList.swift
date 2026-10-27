//
//  FolderList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import SwiftData
import SwiftUI

struct FolderList: View {
    @Query(
        filter: #Predicate<NoteContainer> { folder in
            !folder.isTag
                && !folder.isTrash
                && !folder.isInbox
                && !folder.isBuffer
                && !folder.isStarred
                && !folder.isAllNotes
                && !folder.isArchive
        }
    ) private var folders: [NoteContainer]

    var body: some View {
        ForEach(folders) { folder in
            FolderListEntry(folder: folder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .tag(folder)
        }
    }
}
