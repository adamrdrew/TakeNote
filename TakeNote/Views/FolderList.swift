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
    @Binding var selectedFolder: Folder?

    @Query var folders: [Folder]


    var body: some View {
        List(selection: $selectedFolder) {
            ForEach(folders, id: \.self) { folder in
                FolderListEntry(folder: folder)
            }
        }
    }
}
