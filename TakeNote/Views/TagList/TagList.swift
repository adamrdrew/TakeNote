//
//  TagList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftData
import SwiftUI

public struct TagList: View {
    @Environment(TakeNoteVM.self) private var takeNoteVM

    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]

    public var body: some View {
        ForEach(tags, id: \.self) { tag in
            TagListEntry(tag: tag)
        }
    }
}
