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
    @Environment(TakeNoteVM.self) private var takeNoteVM
    @Query(
        filter: #Predicate<NoteContainer> { folder in !folder.isTag
        }
    ) var folders: [NoteContainer]


    var body: some View {
        ForEach(folders, id: \.self) { folder in
            FolderListEntry(
                folder: folder,
            )
        }

    }

}
