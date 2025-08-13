//
//  NoteEditor.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CodeEditorView
import LanguageSupport
import MarkdownUI
import SwiftData
import SwiftUI

struct NoteEditor: View {
    @Binding var selectedNote: Note?
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var showPreview: Bool = true
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    func generateSummary() async {
        if selectedNote != nil {
            await selectedNote?.generateSummary()
        }
    }

    var body: some View {
        if let note = selectedNote {
            VStack {
                GeometryReader { geometry in
                    CodeEditor(
                        text: Binding(
                            get: { note.content },
                            set: { selectedNote?.content = $0 }
                        ),
                        position: $position,
                        messages: $messages,
                        language: .markdown()
                    )

                    .frame(height: geometry.size.height)
                    .environment(
                        \.codeEditorTheme,
                        colorScheme == .dark
                            ? Theme.defaultDark : Theme.defaultLight
                    )

                }
                if showPreview {
                    Divider()
                    GeometryReader { geometry in

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {

                                Markdown(note.content)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
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

            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        showPreview.toggle()
                    }) {
                        Image(
                            systemName: showPreview
                                ? "eyeglasses.slash"
                                : "eyeglasses"
                        )
                    }

                }

            }
        } else {
            VStack {
                Text("Select a Note")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
