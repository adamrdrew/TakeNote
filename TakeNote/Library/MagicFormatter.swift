//
//  MagicFormatter.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import CryptoKit
import FoundationModels
import SwiftUI
import os

struct MagicFormatterResult {
    let inputHash: String
    let formattedText: String
    let didSucceed: Bool
    let wasCancelled: Bool
    let error: Error?
}

@MainActor
class MagicFormatter: ObservableObject {
    static let failureToken = "TAKENOTE_MAGICFORMAT_FORMATFAILED"

    var session: LanguageModelSession
    let languageModel = SystemLanguageModel.default
    let logger = Logger(subsystem: "com.adammdrew.takenote", category: "MagicFormatter")

    var isAvailable: Bool {
        return languageModel.isAvailable
    }

    // ChatGPT wrote this prompt. I told it what I wanted it to do and it built this out
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
    @Published var sessionCancelled: Bool = false

    init() {
        self.session = LanguageModelSession(instructions: instructions)
        self.session.prewarm()
    }

    func hashFor(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// AFAICT there is no way to cancel a LanguageModelSession once it is off to the races
    /// So to support "cancelling" a MagicFormatter session we sort of fake it
    /// We set sessionCancelled. The magicFormat method will see this after the response comes back and
    /// Throw an error. We plop sessionCancelled onto the MagicFormatterResponse struct as wasCancelled
    /// Our view code handles this by failing silently and doing nothing.
    func cancel() {
        if !session.isResponding {
            return
        }
        if !self.formatterIsBusy {
            return
        }
        self.sessionCancelled = true
        /// We need this for the View to hide the MagicFormatter popover
        self.formatterIsBusy = false
        logger.debug("Cancelling MagicFormatter session")
    }

    func magicFormat(_ text: String) async -> MagicFormatterResult {
        let inputHash = hashFor(text)
        if languageModel.isAvailable == false {
            logger.debug("Attempted to use MagicFormat without Apple Intelligence support.")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText: "Language model is not available.",
                didSucceed: false,
                wasCancelled: false,
                error: nil
            )
        }
        if session.isResponding {
            logger.debug("Attempted to use MagicFormat while session was busy.")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText:
                    "The Language Model is busy. Please try again later.",
                didSucceed: false,
                wasCancelled: false,
                error: nil
            )
        }
        formatterIsBusy = true
        sessionCancelled = false
        let prompt = defaultPrompt + text
        var response: LanguageModelSession.Response<String>

        /// If the session is not respnding and we are all good to do some formatting we create a new session
        /// We do this because there's something cumulative about the session context windows. If we keep re-using
        /// the same session then eventually we get context window size errors even on small documents
        session = LanguageModelSession.init(instructions: instructions)
        do {
            response = try await session.respond(to: prompt)
            if sessionCancelled {
                /// The user has cancelled the MagicFormatter session
                /// There's no real way to cancel a session so we throw an error
                /// sessionCancelled will be plopped onto the MagicFormatterResult as wasCancelled
                /// Which our view will use to fail silently
                logger.debug("A cancelled session resolved.")
                throw NSError(
                    domain: "MagicFormatter",
                    code: 999,
                    userInfo: ["description": "A cancelled session resolved."]
                )
            }
        } catch {
            logger.warning("MagicFormatter Error:\n \(error.localizedDescription)")
            formatterIsBusy = false
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText:
                    "MagicFormatter Error:\n \(error.localizedDescription)",
                didSucceed: false,
                wasCancelled: sessionCancelled,
                error: error
            )
        }
        let formattedDocument = response.content
        formatterIsBusy = false
        sessionCancelled = false
        if formattedDocument.contains(MagicFormatter.failureToken) {
            logger.warning("MagicFormat error token found in generated response")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText:
                    "MagicFormat couldn't figure out how to format your document.",
                didSucceed: false,
                wasCancelled: false,
                error: nil
            )
        }
        return MagicFormatterResult(
            inputHash: inputHash,
            formattedText: unwrapMarkdownFence(formattedDocument),
            didSucceed: true,
            wasCancelled: false,
            error: nil
        )
    }
}
