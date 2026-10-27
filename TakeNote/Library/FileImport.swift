//
//  FileImport.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import Foundation
import SwiftData
import os
import UniformTypeIdentifiers

struct ImportResult: Equatable, Sendable {
    var noteImportCount: Int = 0
    var errorMessages: [String] = []
    
    var errorsEncountered: Bool {
        !errorMessages.isEmpty
    }
    
    var uniqueErrorMessages: [String] {
        Array(Set(errorMessages)).sorted()
    }
    
    func toString() -> String {
        var resultReport = ""
        if noteImportCount > 0 {
            if noteImportCount == 1 {
                resultReport.append(
                    String(
                        localized: "Successfully imported 1 note.",
                        comment: "Import result summary for one successfully imported note."
                    )
                )
            } else {
                resultReport.append(
                    String(
                        localized: "Successfully imported \(noteImportCount) notes.",
                        comment: "Import result summary; the variable is the number of successfully imported notes."
                    )
                )
            }
            resultReport.append("\n")
        }
        if !errorMessages.isEmpty {
            if uniqueErrorMessages.count == 1 {
                resultReport.append(
                    String(
                        localized: "Error Encountered:",
                        comment: "Header shown above a single import error message."
                    )
                )
            } else {
                resultReport.append(
                    String(
                        localized: "Errors Encountered:",
                        comment: "Header shown above multiple import error messages."
                    )
                )
            }
            resultReport.append("\n")
            uniqueErrorMessages.forEach { (message) in
                resultReport.append("\(message)\n")
            }
        }
        return resultReport
    }
}

struct ImportOutcome {
    var result = ImportResult()
    var importedNotes: [Note] = []
}

private func isDirectory(_ url: URL) throws -> Bool {
    try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
}

@MainActor
func folderImport(items: [URL], modelContext: ModelContext, searchIndex: SearchIndexService) -> ImportOutcome {
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "FolderImport")
    var outcome = ImportOutcome()
    let fileManager = FileManager.default
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
    
    for url in items {
        do {
            guard try isDirectory(url) else {
                outcome.result.errorMessages.append(
                    String(
                        localized: "Attempted to import something other than a folder.",
                        comment: "Import error shown when a folder import receives a non-folder item."
                    )
                )
                continue
            }
        } catch {
            logger.error("Failed to inspect import URL \(url.lastPathComponent): \(error.localizedDescription)")
            outcome.result.errorMessages.append(
                String(
                    localized: "Could not inspect \(url.lastPathComponent).",
                    comment: "Import error; the variable is the file or folder name."
                )
            )
            continue
        }

        let fileURLs: [URL]
        do {
            let children = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )
            fileURLs = children.filter { child in
                do {
                    return try !isDirectory(child)
                } catch {
                    logger.error("Failed to inspect child URL \(child.lastPathComponent): \(error.localizedDescription)")
                    outcome.result.errorMessages.append(
                        String(
                            localized: "Could not inspect \(child.lastPathComponent).",
                            comment: "Import error; the variable is the file or folder name."
                        )
                    )
                    return false
                }
            }
        } catch {
            logger.error("Failed to read folder \(url.lastPathComponent): \(error.localizedDescription)")
            outcome.result.errorMessages.append(
                String(
                    localized: "Could not read \(url.lastPathComponent).",
                    comment: "Import error; the variable is the folder name."
                )
            )
            continue
        }

        let newFolder = NoteContainer(
            name: url.lastPathComponent,
        )
        newFolder.isTag = false
        newFolder.isInbox = false
        newFolder.isTrash = false
        newFolder.canBeDeleted = true
        
        modelContext.insert(newFolder)

        let fileImportResults = fileImport(
            items: fileURLs,
            modelContext: modelContext,
            searchIndex: searchIndex,
            folder: newFolder
        )
        outcome.result.noteImportCount += fileImportResults.result.noteImportCount
        outcome.result.errorMessages += fileImportResults.result.errorMessages
        outcome.importedNotes += fileImportResults.importedNotes
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save modelContext: \(error)")
            outcome.result.errorMessages.append(
                String(
                    localized: "Failed to save to database.",
                    comment: "Import error shown when imported data could not be saved."
                )
            )
        }
    }
    
    return outcome
}



@MainActor
func fileImport(items: [URL], modelContext: ModelContext, searchIndex: SearchIndexService, folder: NoteContainer) -> ImportOutcome {
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "FileImport")
    var noteImported = false
    var outcome = ImportOutcome()
    for url in items {
        if url.pathExtension != "md" && url.pathExtension != "txt" {
            outcome.result.errorMessages.append(
                String(
                    localized: "Attempted to import an unsupported file.",
                    comment: "Import error shown for unsupported file types."
                )
            )
            continue
        }
        let fileContents: String
        do {
            fileContents = try String(
                contentsOf: url,
                encoding: .utf8
            )
        } catch {
            logger.error("Failed to load \(url.lastPathComponent): \(error.localizedDescription)")
            outcome.result.errorMessages.append(
                String(
                    localized: "Loading \(url.lastPathComponent) failed.",
                    comment: "Import error; the variable is the file name."
                )
            )
            continue
        }
        let newNote = Note(folder: folder)
        newNote.setTitle(url.lastPathComponent)
        newNote.setContent(fileContents)
        modelContext.insert(newNote)
        searchIndex.reindex(note: newNote)
        outcome.result.noteImportCount += 1
        outcome.importedNotes.append(newNote)
        noteImported = true
    }
    if !noteImported {
        outcome.result.errorMessages.append(
            String(
                localized: "No notes were imported.",
                comment: "Import result shown when no supported note files were imported."
            )
        )
        return outcome
    }
    do {
        try modelContext.save()
    } catch {
        logger.error("Failed to save modelContext: \(error)")
        outcome.result.errorMessages.append(
            String(
                localized: "Failed to save to database.",
                comment: "Import error shown when imported data could not be saved."
            )
        )
    }
    return outcome
}

@MainActor
func generateImportedNoteSummaries(for notes: [Note]) async {
    for note in notes {
        guard !Task.isCancelled else { return }
        await note.generateSummary()
    }
}
