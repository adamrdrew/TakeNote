//
//  MagicFormatter.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import FoundationModels
import SwiftUI

struct MagicFormatterResult {
    let formattedText: String
    let didSucceed: Bool
    let error: Error?
}

@MainActor
class MagicFormatter: ObservableObject {
    static let failureToken = "FORMATFAILED"
    let languageModel = SystemLanguageModel.default

    var isAvailable: Bool {
        return languageModel.isAvailable
    }

    var instructions: String = """
        ROLE
        You are a Markdown formatting assistant. You receive an unformatted plain-text document and return only a well-structured Markdown version.

        CORE RULES
        - Output ONLY the formatted Markdown. Do not add commentary, headers like “Here’s…”, or code fences around the whole document.
        - Do not invent content, facts, links, or sections. Preserve the author’s words and intent.
        - Be helpful but conservative: reorganize for clarity, add headings/lists where obvious, but don’t rewrite prose.
        - If you cannot confidently improve the formatting (e.g., input is already properly formatted, or instructions are unclear), output EXACTLY: \(MagicFormatter.failureToken)

        WHAT TO DO
        - Headings: infer a single H1 title if obvious (first line as title), otherwise start at H2. Use `#`, `##`, `###`.
        - Lists: convert enumerations/bullets into `-` or `1.` lists; keep sublists with indentation.
        - Emphasis: keep existing emphasis; selectively add **bold** for section labels and *italics* for terms if it aids readability.
        - Code: wrap snippets/commands in backticks; use fenced blocks with language when clear (e.g., ```swift, ```bash).
        - Quotes: turn quoted passages into `>`.
        - Tables: where the text clearly tabulates (key: value pairs repeated), convert to a simple Markdown table.
        - Tasks: recognize lines that look like todos and format as `- [ ]` items.
        - Links: if the text includes naked URLs, format as `[text](url)` using the given visible text; never invent URLs or titles.

        WHAT NOT TO DO
        - Don’t change meaning, tone, or order without good reason.
        - Don’t summarize or shorten unless the text explicitly asks you to.
        - Don’t add metadata, front-matter, or footers.
        - Don’t wrap the entire output in a single code fence.

          ABSOLUTE OUTPUT RULES
            - Do **NOT** wrap the entire output in code fences of any kind (no ```markdown, ```md, ```, or ~~~).
            - Do **NOT** add any lead-in text or commentary.
            - Do **NOT** include a final code fence line.

         WRONG (do not do this):
            ```markdown
            # Title
            ```
            RIGHT (do this instead):
            # Title
            

        MINI CHEAT-SHEET
        # Title
        ## Section
        ### Subsection
        - Bullet
          - Nested bullet
        1. Numbered
        `inline code`
        ```language
        block code
        ```
        > Block quote
        - [ ] Task

        EXAMPLES

        Input:
        project plan
        goals
        - ship mac app
        - test on beta
        steps
        1 set up ci
        2 sign builds
        env vars: API_KEY, TENANT

        Output:
        # Project Plan
        ## Goals
        - Ship Mac app
        - Test on beta

        ## Steps
        1. Set up CI
        2. Sign builds

        ## Environment Variables
        `API_KEY`, `TENANT`

        FAILURE EXAMPLE
        If the input is already valid Markdown or is a single sentence with nothing to format, reply with:
        \(MagicFormatter.failureToken)
        """
    var defaultPrompt: String = "Document to format in markdown:\n\n"

    @Published var formatterIsBusy: Bool = false

    init() {
    }
    
    private func removeMarkdownClosures(_ input: String) -> String {
        //If the first line of the input is ```markdown and the last line is ```
        // remove the first and last lines and return
        if input.hasPrefix("```markdown") && input.hasSuffix("```") {
            return String(input.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().dropLast().joined(separator: "\n"))
        }
        return input
    }

    func magicFormat(_ text: String) async -> MagicFormatterResult {
        if languageModel.isAvailable == false {
            return MagicFormatterResult(
                formattedText: "Language model is not available.",
                didSucceed: false,
                error: nil
            )
        }
        formatterIsBusy = true
        let prompt = defaultPrompt + text
        var response: LanguageModelSession.Response<String>
        let session = LanguageModelSession(instructions: instructions)
        if session.isResponding {
            formatterIsBusy = false
            return MagicFormatterResult(
                formattedText:
                    "Model is busy formatting your text. Please try again later.",
                didSucceed: false,
                error: nil
            )
        }
        do {
            response = try await session.respond(to: prompt)
        } catch {
            formatterIsBusy = false
            return MagicFormatterResult(
                formattedText: "MagicFormatter Error:\n \(error.localizedDescription)",
                didSucceed: false,
                error: error
            )
        }
        let formattedDocument = response.content
        formatterIsBusy = false
        if formattedDocument == MagicFormatter.failureToken {
            return MagicFormatterResult(
                formattedText:
                    "Your input does not seem to be a valid document to format. Please try again.",
                didSucceed: false,
                error: nil
            )
        }
        return MagicFormatterResult(
            formattedText: removeMarkdownClosures(formattedDocument),
            didSucceed: true,
            error: nil
        )
    }
}
