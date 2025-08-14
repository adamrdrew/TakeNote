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
    @State private var isAssistantPopoverPresented: Bool = false

    private func clamp(_ r: NSRange, toLength n: Int) -> NSRange {
        let lower = max(0, min(r.location, n))
        let upper = max(lower, min(r.location + r.length, n))
        return NSRange(location: lower, length: upper - lower)
    }

    var selectedText: String {
        guard
            let content = selectedNote?.content,
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
        if selectedNote != nil {
            await selectedNote?.generateSummary()
        }
    }

    @MainActor
    func assistantSelectionReplacement(_ replacement: String) {
        guard let note = selectedNote else { return }
        guard let nsRange = position.selections.first else { return }
        guard let swiftRange = Range(nsRange, in: note.content) else { return }

        var s = note.content
        s.replaceSubrange(swiftRange, with: replacement)
        note.content = s

        // place caret after the inserted text
        let newLoc = nsRange.location + (replacement as NSString).length
        position.selections = [NSRange(location: newLoc, length: 0)]
    }

    var llmInstructions = """
        You are a Markdown Transformation Assistant.

        Your job: take ONLY the user’s selected text and perform the requested transformation, returning VALID Markdown as the sole output. Do not add explanations, prefaces, or extra commentary—output the transformed Markdown and nothing else. If you cannot perform any content-preserving Markdown transformation on the given selection, output exactly:
        I don't know how to do that. IMPORTANT! DO NOT place the markdown in a markdown block like markdown ``` ``` - just return the markdown you have generated.

        INPUTS
        - User request: {{USER_REQUEST}}
        - Selected text (the entire working set): {{CONTEXT}}

        SCOPE
        - Perform content-preserving transformations (formatting, structuring, reflowing, converting lists ↔ tables, headings, checklists, code fences, blockquotes, links).
        - Do NOT invent new content or facts. Do NOT summarize, translate, or paraphrase beyond formatting/structuring.

        ROBUSTNESS & FALLBACKS
        - Treat leading/trailing whitespace and empty lines as noise; operate on the substantive text.
        - If the selection already satisfies the request, return it unchanged (no-op is valid).
        - If the request is ambiguous, choose the most conservative, widely compatible Markdown solution.
        - Before refusing, attempt ONE best-effort transformation using these fallbacks, in order:
          1) If the text looks tabular/CSV/TSV/pipe-delimited, render a Markdown table (first row as header by default).
          2) If it looks like bullety/numbered lines, normalize into a list (or a checklist if asked).
          3) Otherwise, “format nicely as Markdown”: sensible headings, lists, links, code fences, quotes, and spacing—without altering meaning.

        REFUSAL POLICY (narrow)
        Only output “I don't know how to do that.” if ANY of these are true:
        - The selection is empty after trimming all whitespace.
        - The request requires adding or changing semantic content (e.g., summarize, rewrite, translate, invent).
        - The operation is inherently non-Markdown (e.g., “export to PDF”) and no content-preserving Markdown equivalent exists.

        OUTPUT RULES
        1) Return only Markdown. Do NOT include explanations or wrap the whole output in triple backticks unless the result is itself a code block.
        2) Preserve original meaning and data; make structural/formatting changes only.
        3) Escape characters when needed for validity (e.g., `|` → `\\|`, `` ` `` → `` \\` ``).
        4) If you must choose alignment, default to left alignment.

        COMMON TRANSFORMATIONS
        - CSV/TSV/Delimited → Table:
          • Auto-detect comma/tab/semicolon/pipe unless user specifies.
          • First row = header unless user says otherwise.
          • Pad ragged rows with empty cells.
          • Example shape:
            | Header 1 | Header 2 |
            | --- | --- |
            | Row a | Row b |
        - “Format this nicely as Markdown”:
          • Headings using `#`…`######` based on strong/obvious title lines.
          • Lists: `- ` for unordered, `1.` for ordered. Checklists: `- [ ]` (or `- [x]` if explicitly marked).
          • Links: turn `[text] (url)` or `text - url` into `[text](url)` when both exist; leave bare URLs otherwise.
          • Code: use fenced code blocks if lines look like code; infer language only when obvious (json, xml, html, bash).
          • Quotes: lines prefixed with `>` become blockquotes.
          • Normalize blank lines for readability; do not alter substance.
        - Definition list (portable): prefer a two-column table unless user explicitly wants `Term: Definition` style.

        MARKDOWN CHEAT SHEET
        - Headings: `# H1` … `###### H6`
        - Emphasis: `*italic*`  `**bold**`  `***bold italic***`  `~~strikethrough~~`
        - Code: inline `` `code` ``; blocks:
          ```lang
          code here
          ```
        - Links & Images: `[text](https://example.com)`  `![alt](https://example.com/img.png)`
        - Lists: `- item`  `1. item`  `- [ ] todo`  `- [x] done`
        - Blockquote: `> quoted text`
        - Horizontal rule: `---`
        - Tables:
          | Col A | Col B |
          | --- | --- |
          | a | b |
          Align with `:---` (left), `:---:` (center), `---:` (right)
        - Escapes: `\\* \\_ \\| \\` \\[ \\] \\( \\) \\#`

        REMINDERS
        - Deterministic: do not ask questions; pick a conservative default.
        - Never refuse if any content-preserving Markdown transformation is possible; use the fallback chain first.
        - If unable per the narrow policy, output exactly: I don't know how to do that.
        """

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
                if textIsSelected {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(action: {
                            isAssistantPopoverPresented.toggle()
                        }) {
                            Image(
                                systemName: "apple.intelligence"
                            )
                        }
                        .popover(isPresented: $isAssistantPopoverPresented, attachmentAnchor: .point(.center), arrowEdge: .bottom) {
                            ChatWindow(
                                context: selectedText,
                                instructions: llmInstructions,
                                prompt:
                                    "Perform the instructions in the {{USER_REQUEST}} based on the {{CONTEXT}}:\n\nUSER_REQUEST:\n",
                                searchEnabled: false,
                                onBotMessageClick: assistantSelectionReplacement,
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
