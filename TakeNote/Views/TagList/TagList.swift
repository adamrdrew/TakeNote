//
//  TagList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

public struct TagList: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    var onDelete: ((_ deletedFolder: NoteContainer) -> Void) = {
        deletedFolder in
    }

    public var body: some View {
        ForEach(tags, id: \.self) { tag in
            TagListEntry(tag: tag, onDelete: onDelete)
        }
    }
}
