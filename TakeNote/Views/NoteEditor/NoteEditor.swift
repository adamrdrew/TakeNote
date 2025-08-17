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
    @Binding var openNote: Note
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var showPreview: Bool = true
    @State private var magicFormatterErrorMessage: String = ""
    @State var magicFormatterErrorIsPresented: Bool = false
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isAssistantPopoverPresented: Bool = false
    @StateObject private var magicFormatter = MagicFormatter()

    let logger = Logger(
        subsystem: "com.adammdrew.takenote",
        category: "NoteEditor"
    )

    private func clamp(_ r: NSRange, toLength n: Int) -> NSRange {
        let lower = max(0, min(r.location, n))
        let upper = max(lower, min(r.location + r.length, n))
        return NSRange(location: lower, length: upper - lower)
    }

    func doMagicFormat() {
        if magicFormatter.formatterIsBusy { return }
        if openNote.content.isEmpty { return }
        Task {
            let result = await magicFormatter.magicFormat(
                openNote.content
            )
            if result.wasCancelled {
                return
            }
            if !result.didSucceed {
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage = result.formattedText
                return
            }
            let currentContentHash = magicFormatter.hashFor(openNote.content)
            if currentContentHash != result.inputHash {
                logger.critical(
                    "Mismatch between MagicFormat input and current note content."
                )
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage =
                    "Mismatch between MagicFormat input and current note content."
                return
            }
            openNote.content = result.formattedText
            return
        }

    }

    var selectedText: String {
        guard
            !openNote.content.isEmpty,
            let raw = position.selections.first
        else { return "" }

        let ns = openNote.content as NSString
        let clamped = clamp(raw, toLength: ns.length)
        return ns.substring(with: clamped)
    }

    var textIsSelected: Bool {
        return selectedText.isEmpty == false
    }

    func generateSummary() async {
        await openNote.generateSummary()
    }

    @MainActor
    func assistantSelectionReplacement(_ replacement: String) {
        guard let nsRange = position.selections.first else { return }
        guard let swiftRange = Range(nsRange, in: openNote.content) else {
            return
        }

        var s = openNote.content
        s.replaceSubrange(swiftRange, with: replacement)
        openNote.content = s

        // place caret after the inserted text
        let newLoc = nsRange.location + (replacement as NSString).length
        position.selections = [NSRange(location: newLoc, length: 0)]
    }

    let llmInstructions = MARKDOWN_ASSISTANT_PROMPT

    var Editor: some View {
        GeometryReader { geometry in
            CodeEditor(
                text: $openNote.content,
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

    var body: some View {
        ZStack {
            if !showPreview {
                Editor
            }
            if showPreview {
                GeometryReader { geometry in

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {

                            Markdown(openNote.content)
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
        .onChange(of: openNote.id) { _, _ in
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
    }
}
