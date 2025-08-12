//
//  NoteLabelList.swift
//  TakeNote
//
//  Created by Adam Drew on 8/9/25.
//

import SwiftUI
import SwiftData

public struct TagList: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(
        filter: #Predicate<NoteContainer> { folder in folder.isTag
        }
    ) var tags: [NoteContainer]
        
    @Binding var selectedFolder: NoteContainer?
        
    public var body: some View {
        List(selection: $selectedFolder) {
            ForEach(tags, id: \.self) { tag in
                TagListEntry(tag: tag)
            }
        }
    }
}
