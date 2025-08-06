//
//  NoteEditor.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct NoteEditor: View {
    @Binding var selectedNote: Note?

    var body: some View {
        if let note = selectedNote {
            VStack {
                GeometryReader { geometry in
                    ScrollView {
                        TextEditor(
                            text: Binding(
                                get: { note.content },
                                set: { selectedNote?.content = $0 }
                            )
                        )
                        .font(.system(size: 16).monospaced())
                        .frame(height: geometry.size.height)
                    }
                }
                Divider()
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Markdown(note.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .frame(
                            minHeight: geometry.size.height,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                    }
                }

            }
        } else {
            Text("Select a Note")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
