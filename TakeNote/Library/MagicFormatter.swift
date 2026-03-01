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
}

@MainActor
@Observable
class MagicFormatter {

    var session: LanguageModelSession
    let languageModel = SystemLanguageModel.default
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "MagicFormatter")

    var isAvailable: Bool {
        return languageModel.isAvailable
    }


    var defaultPrompt: String = "Document to format in markdown:\n\n"

    var formatterIsBusy: Bool = false
    var sessionCancelled: Bool = false

    init() {
        self.session = LanguageModelSession(instructions: MAGIC_FORMAT_PROMPT)
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
                wasCancelled: false
            )
        }
        if session.isResponding {
            logger.debug("Attempted to use MagicFormat while session was busy.")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText:
                    "The Language Model is busy. Please try again later.",
                didSucceed: false,
                wasCancelled: false
            )
        }
        formatterIsBusy = true
        sessionCancelled = false
        let prompt = defaultPrompt + text
        var response: LanguageModelSession.Response<String>

        /// If the session is not respnding and we are all good to do some formatting we create a new session
        /// We do this because there's something cumulative about the session context windows. If we keep re-using
        /// the same session then eventually we get context window size errors even on small documents
        session = LanguageModelSession.init(instructions: MAGIC_FORMAT_PROMPT)
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
                wasCancelled: sessionCancelled
            )
        }
        let formattedDocument = response.content
        formatterIsBusy = false
        sessionCancelled = false
        if formattedDocument.contains(MAGIC_FORMAT_FAILURE_TOKEN) {
            logger.warning("MagicFormat error token found in generated response")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText:
                    "MagicFormat couldn't figure out how to format your document.",
                didSucceed: false,
                wasCancelled: false
            )
        }
        return MagicFormatterResult(
            inputHash: inputHash,
            formattedText: unwrapMarkdownFence(formattedDocument),
            didSucceed: true,
            wasCancelled: false
        )
    }
}
