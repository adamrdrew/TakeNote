//
//  FileImport.swift
//  TakeNote
//
//  Created by Adam Drew on 8/16/25.
//

import SwiftUI
import SwiftData
import os
import UniformTypeIdentifiers

struct ImportResult {
    var noteImportCount: Int = 0
    var errorMessages : [String] = []
    
    var errorsEncountered : Bool  {
        errorMessages.count > 0
    }
    
    var uniqueErrorMessages : [String] {
        Array(Set(errorMessages))
    }
    
    func toString() -> String {
        var resultReport = ""
        if noteImportCount > 0 {
            resultReport.append("Successfully imported \(noteImportCount) notes.\n")
        }
        if errorMessages.count > 0  {
            resultReport.append("Error\(uniqueErrorMessages.count == 1 ? "" : "s") Encountered:\n")
            uniqueErrorMessages.forEach { (message) in
                resultReport.append("\(message)\n")
            }
        }
        return resultReport
    }
}

private func isDirectory(_ url: URL) -> Bool {
    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
}

@MainActor
func folderImport(items: [URL], modelContext: ModelContext, searchIndex: SearchIndexService) -> ImportResult {
    let logger = Logger(subsystem: "com.adammdrew.TakeNote", category: "FolderImport")
    var result = ImportResult()
    let fileManager = FileManager.default
    var fileURLs : [URL] = []
    let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
    
    for url in items {
        if !isDirectory(url) {
            result.errorMessages.append("Attempted to import something other than a folder.")
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
        
        if let children = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles]) {
            fileURLs = children.filter { !isDirectory($0) }
        }
        
        let fileImportResults = fileImport(items: fileURLs, modelContext: modelContext, searchIndex: searchIndex, folder: newFolder)
        result.errorMessages += fileImportResults.errorMessages
        
        do {
            try modelContext.save()
        } catch {
            logger.critical("Failed to save modelContext: \(error)")
            result.errorMessages.append("Failed to save to database.")
        }
    }
    
    return result
}



@MainActor
func fileImport(items: [URL], modelContext: ModelContext, searchIndex: SearchIndexService, folder: NoteContainer) -> ImportResult {
    let logger = Logger(subsystem: "com.adammdrew.TakeNote", category: "FileImport")
    var noteImported = false
    var result = ImportResult()
    for url in items {
        if url.pathExtension != "md" && url.pathExtension != "txt" {
            result.errorMessages.append("Attempted to import an unsupported file.")
            continue
        }
        guard
            let fileContents = try? String(
                contentsOf: url,
                encoding: .utf8
            )
        else {
            result.errorMessages.append("Loading a file failed.")
            continue
        }
        let newNote = Note(folder: folder)
        newNote.title = url.lastPathComponent
        newNote.content = fileContents
        modelContext.insert(newNote)
        Task { await newNote.generateSummary() }
        searchIndex.reindex(note: newNote)
        noteImported = true
    }
    if !noteImported {
        result.errorMessages.append("No notes were imported.")
        return result
    }
    do {
        try modelContext.save()
    } catch {
        logger.critical("Failed to save modelContext: \(error)")
        result.errorMessages.append("Failed to save to database.")
    }
    return result
}
