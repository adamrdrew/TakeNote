//
//  MagicFormatter.swift
//  TakeNote
//
//  Created by Adam Drew on 8/14/25.
//

import CryptoKit
import Foundation
import FoundationModels
import Observation
import os

struct MagicFormatterResult: Equatable, Sendable {
    let inputHash: String
    let formattedText: String
    let didSucceed: Bool
    let wasCancelled: Bool
}

private enum MagicFormatterError: LocalizedError {
    case cancelledSessionResolved

    var errorDescription: String? {
        switch self {
        case .cancelledSessionResolved:
            String(
                localized: "A cancelled session resolved.",
                comment: "Internal Magic Format error shown if a cancelled AI formatting request still returns a response."
            )
        }
    }
}

@MainActor
@Observable
final class MagicFormatter {

    @ObservationIgnored
    private var session: LanguageModelSession
    @ObservationIgnored
    private let languageModel = TakeNoteLanguageModels.contentTransformation
    @ObservationIgnored
    private let fallbackLanguageModel = TakeNoteLanguageModels.contentTransformationFallback
    @ObservationIgnored
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "MagicFormatter")

    var isAvailable: Bool {
        languageModel.isAvailable || fallbackLanguageModel.isAvailable
    }

    @ObservationIgnored
    private let defaultPrompt = "Document to format as Markdown:\n\n"

    var formatterIsBusy: Bool = false
    @ObservationIgnored
    private var sessionCancelled: Bool = false

    init() {
        self.session = Self.makeSession(model: TakeNoteLanguageModels.contentTransformation)
        self.session.prewarm()
    }

    private static func makeSession(model: SystemLanguageModel) -> LanguageModelSession {
        LanguageModelSession(
            model: model,
            instructions: TakeNoteLanguageModels.instructions(MAGIC_FORMAT_PROMPT)
        )
    }

    func hashFor(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    func cancel() {
        if !session.isResponding {
            return
        }
        if !self.formatterIsBusy {
            return
        }
        self.sessionCancelled = true
        self.formatterIsBusy = false
        logger.debug("Cancelling MagicFormatter session")
    }

    func magicFormat(_ text: String) async -> MagicFormatterResult {
        let inputHash = hashFor(text)
        if !isAvailable {
            logger.debug("Attempted to use MagicFormat without Apple Intelligence support.")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText: String(
                    localized: "Language model is not available.",
                    comment: "Magic Format error shown when Apple Intelligence is unavailable."
                ),
                didSucceed: false,
                wasCancelled: false
            )
        }
        if session.isResponding {
            logger.debug("Attempted to use MagicFormat while session was busy.")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText: String(
                    localized: "The Language Model is busy. Please try again later.",
                    comment: "Magic Format error shown when the local AI model is already responding."
                ),
                didSucceed: false,
                wasCancelled: false
            )
        }
        formatterIsBusy = true
        sessionCancelled = false
        defer {
            formatterIsBusy = false
            sessionCancelled = false
        }

        let prompt = TakeNoteLanguageModels.prompt(defaultPrompt + text)
        var response: LanguageModelSession.Response<String>

        session = Self.makeSession(model: languageModel.isAvailable ? languageModel : fallbackLanguageModel)
        do {
            response = try await session.respond(to: prompt)
            if sessionCancelled {
                logger.debug("A cancelled session resolved.")
                throw MagicFormatterError.cancelledSessionResolved
            }
        } catch let error where shouldRetryWithFallback(error) && fallbackLanguageModel.isAvailable && !sessionCancelled {
            logger.debug("MagicFormatter content transformation model unsupported; retrying with standard model.")
            session = Self.makeSession(model: fallbackLanguageModel)
            do {
                response = try await session.respond(to: prompt)
                if sessionCancelled {
                    logger.debug("A cancelled fallback session resolved.")
                    throw MagicFormatterError.cancelledSessionResolved
                }
            } catch {
                logger.warning("MagicFormatter fallback error:\n \(error.localizedDescription)")
                return MagicFormatterResult(
                    inputHash: inputHash,
                    formattedText: String(
                        localized: "MagicFormatter Error:\n \(error.localizedDescription)",
                        comment: "Magic Format fallback error; the variable is the underlying error description."
                    ),
                    didSucceed: false,
                    wasCancelled: sessionCancelled
                )
            }
        } catch {
            logger.warning("MagicFormatter Error:\n \(error.localizedDescription)")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText: String(
                    localized: "MagicFormatter Error:\n \(error.localizedDescription)",
                    comment: "Magic Format error; the variable is the underlying error description."
                ),
                didSucceed: false,
                wasCancelled: sessionCancelled
            )
        }
        let formattedDocument = response.content
        if formattedDocument.contains(MAGIC_FORMAT_FAILURE_TOKEN) {
            logger.warning("MagicFormat error token found in generated response")
            return MagicFormatterResult(
                inputHash: inputHash,
                formattedText: String(
                    localized: "MagicFormat couldn't figure out how to format your document.",
                    comment: "Magic Format error shown when the AI model returns the explicit formatting failure token."
                ),
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

    private func shouldRetryWithFallback(_ error: Error) -> Bool {
        if let languageModelError = error as? LanguageModelError,
           case .unsupportedCapability = languageModelError {
            return true
        }
        return error.localizedDescription.localizedCaseInsensitiveContains("requested capability")
            || error.localizedDescription.localizedCaseInsensitiveContains("unsupported capability")
    }
}
