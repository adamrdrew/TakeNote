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
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]

    var body: some View {
        ForEach(folders, id: \.self) { folder in
            if folder.isBuffer || folder.isInbox || folder.isTag || folder.isTrash || folder.isStarred {
                EmptyView()
            } else {
                FolderListEntry(
                    folder: folder,
                )
            }

        }

    }

}
