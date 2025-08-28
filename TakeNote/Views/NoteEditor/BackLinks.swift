//
//  BackLinks.swift
//  TakeNote
//
//  Created by Adam Drew on 8/27/25.
//

import SwiftData
import SwiftUI

struct BackLinks: View {
    @Environment(\.modelContext) var modelContext: ModelContext
    @Environment(TakeNoteVM.self) var takeNoteVM: TakeNoteVM

    @State var selectedNoteHasBacklinks: Bool = false
    @State var linkManager: NoteLinkManager? = nil
    @State var backLinkedNotes: [Note] = []

    var body: some View {
        VStack {
            Text("Backlinks")
                .font(.headline)
                .padding()
            if !selectedNoteHasBacklinks || linkManager == nil {
                Text("No Backlinks Found")
            } else {
                List {
                    ForEach(backLinkedNotes) { note in
                        Link(
                            note.title,
                            destination: URL(string: note.getURL())!
                        )
                    }
                }
            }
        }
        .frame(width: 200, height: 200)
        .onAppear {
            linkManager = NoteLinkManager(modelContext: modelContext)
            backLinkedNotes = linkManager!.getNotesThatLinkTo(
                takeNoteVM.openNote!
            )
            selectedNoteHasBacklinks = backLinkedNotes.isEmpty == false
        }

    }
}
