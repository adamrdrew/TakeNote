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
import os

struct NoteEditor: View {
    @Binding var openNote: Note?
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var showPreview: Bool = true
    @State private var magicFormatterErrorMessage: String = ""
    @State var magicFormatterErrorIsPresented: Bool = false
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isAssistantPopoverPresented: Bool = false
    @StateObject private var magicFormatter = MagicFormatter()
    
    let logger = Logger(subsystem: "com.adammdrew.takenote", category: "NoteEditor")

    private func clamp(_ r: NSRange, toLength n: Int) -> NSRange {
        let lower = max(0, min(r.location, n))
        let upper = max(lower, min(r.location + r.length, n))
        return NSRange(location: lower, length: upper - lower)
    }

    func doMagicFormat() {
        if magicFormatter.formatterIsBusy { return }
        if openNote == nil { return }
        if openNote!.content.isEmpty { return }
        Task {
            let result = await magicFormatter.magicFormat(
                openNote!.content
            )
            if result.wasCancelled {
                return
            }
            if !result.didSucceed {
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage = result.formattedText
                return
            }
            let currentContentHash = magicFormatter.hashFor(openNote!.content)
            if currentContentHash != result.inputHash {
                logger.critical("Mismatch between MagicFormat input and current note content.")
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage = "Mismatch between MagicFormat input and current note content."
                return
            }
            openNote!.content = result.formattedText
            return
        }

    }

    var selectedText: String {
        guard
            let content = openNote?.content,
            !content.isEmpty,
            let raw = position.selections.first
        else { return "" }

        let ns = content as NSString
        let clamped = clamp(raw, toLength: ns.length)
        return ns.substring(with: clamped)
    }

    var textIsSelected: Bool {
        return selectedText.isEmpty == false
    }

    func generateSummary() async {
        if openNote != nil {
            await openNote?.generateSummary()
        }
    }

    @MainActor
    func assistantSelectionReplacement(_ replacement: String) {
        guard let note = openNote else { return }
        guard let nsRange = position.selections.first else { return }
        guard let swiftRange = Range(nsRange, in: note.content) else { return }

        var s = note.content
        s.replaceSubrange(swiftRange, with: replacement)
        note.content = s

        // place caret after the inserted text
        let newLoc = nsRange.location + (replacement as NSString).length
        position.selections = [NSRange(location: newLoc, length: 0)]
    }

    let llmInstructions = MARKDOWN_ASSISTANT_PROMPT

    var body: some View {
        if let note = openNote {
            ZStack {
                if !showPreview {
                    GeometryReader { geometry in

                        CodeEditor(
                            text: Binding(
                                get: { note.content },
                                set: { openNote?.content = $0 }
                            ),
                            position: $position,
                            messages: $messages,
                            language: .markdown(),
                            layout: CodeEditor.LayoutConfiguration(
                                showMinimap: false,
                                wrapText: true
                            )
                        )
                        .onExitCommand(perform: {
                            withAnimation {
                                showPreview.toggle()
                            }
                        })
                        .disabled(magicFormatter.formatterIsBusy)
                        .frame(height: geometry.size.height)
                        .environment(
                            \.codeEditorTheme,
                            colorScheme == .dark
                                ? Theme.defaultDark : Theme.defaultLight
                        )
                    }
                }
                if showPreview {
                    GeometryReader { geometry in

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {

                                Markdown(note.content)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(24)

                            }
                            .frame(
                                minHeight: geometry.size.height,
                                maxHeight: .infinity,
                                alignment: .top
                            )

                        }
                        .onExitCommand(perform: {
                            showPreview.toggle()
                        })
                        .onTapGesture {
                            withAnimation {
                                showPreview.toggle()
                            }
                        }
                    }
                }

            }
            .onChange(of: openNote?.id) { _, _ in
                showPreview = true
            }
            .sheet(isPresented: $magicFormatter.formatterIsBusy) {
                VStack {
                    AIMessage(message: "Magic Formatting...", font: .headline)
                        .padding()
                    Button("Cancel", role: .cancel) {
                        magicFormatter.cancel()
                    }
                    .padding()
                }
            }
            .alert(
                magicFormatterErrorMessage,
                isPresented: $magicFormatterErrorIsPresented
            ) {

                Button("OK") {
                    magicFormatterErrorIsPresented = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        withAnimation {
                            showPreview.toggle()
                        }
                    }) {
                        Image(
                            systemName: showPreview
                                ? "eye.slash"
                                : "eye"
                        )
                    }
                    .help(showPreview ? "Hide Preview" : "Show Preview")

                }
                if magicFormatter.isAvailable {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(action: {
                            doMagicFormat()
                        }) {
                            Image(
                                systemName: "wand.and.sparkles"
                            )
                        }
                        .disabled(magicFormatter.formatterIsBusy)
                        .help("Magic Format")
                    }

                }

                if textIsSelected {

                    ToolbarItem(placement: .secondaryAction) {
                        Button(action: {
                            isAssistantPopoverPresented.toggle()
                        }) {
                            Image(
                                systemName: "apple.intelligence"
                            )
                        }
                        .help("AI Markdown Assistant")
                        .popover(
                            isPresented: $isAssistantPopoverPresented,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .bottom
                        ) {
                            ChatWindow(
                                context: selectedText,
                                instructions: llmInstructions,
                                prompt:
                                    "Perform the instructions in the {{USER_REQUEST}} based on the {{CONTEXT}}:\n\nUSER_REQUEST:\n",
                                searchEnabled: false,
                                onBotMessageClick:
                                    assistantSelectionReplacement,
                                toolbarVisible: false,
                                useHistory: false

                            )
                            .frame(minWidth: 300, minHeight: 400)
                        }

                    }
                }

            }

        } else {
            VStack {
                Spacer()
                Text("No Note Selected")
                    .font(.title)
                    .padding()
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }
}
