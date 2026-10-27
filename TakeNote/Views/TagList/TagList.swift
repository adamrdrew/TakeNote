//
//  TagList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

struct TagList: View {
    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) private var tags: [NoteContainer]

    var body: some View {
        ForEach(tags) { tag in
            TagListEntry(tag: tag)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .tag(tag)
        }
    }
}
