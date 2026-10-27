//
//  SystemFolderReconciler.swift
//  TakeNote
//
//  Created by Adam Drew on 8/31/25.
//

import Foundation
import os
import SwiftData

private enum SystemFolderReconcilerError: LocalizedError {
    case missingCanonicalSystemFolder

    var errorDescription: String? {
        switch self {
        case .missingCanonicalSystemFolder:
            String(
                localized: "Could not choose a canonical system folder.",
                comment: "Internal recovery error shown in logs when duplicate system folders cannot be reconciled."
            )
        }
    }
}

@MainActor
final class SystemFolderReconciler {
    private let ctx: ModelContext
    private let vm: TakeNoteVM
    private var isRunning = false
    private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "SystemFolderReconciler")

    init(ctx: ModelContext, vm: TakeNoteVM) {
        self.ctx = ctx
        self.vm = vm
    }

    func runOnce() throws {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        let inbox = try reconcile(match: #Predicate { $0.isInbox })
        let trash = try reconcile(match: #Predicate { $0.isTrash })
        let buffer = try reconcile(match: #Predicate { $0.isBuffer })
        let starred = try reconcile(match: #Predicate { $0.isStarred })
        let allNotes = try reconcile(match: #Predicate { $0.isAllNotes })
        let archive = try reconcile(match: #Predicate { $0.isArchive })

        // Even if reconcile() returned nil (because count == 0 or 1),
        // we still want the VM to hold the current canonical (if one exists).
        vm.inboxFolder  = inbox  ?? fetchSingle(#Predicate { $0.isInbox })
        vm.trashFolder  = trash  ?? fetchSingle(#Predicate { $0.isTrash })
        vm.bufferFolder = buffer ?? fetchSingle(#Predicate { $0.isBuffer })
        vm.starredFolder = starred ?? fetchSingle(#Predicate { $0.isStarred })
        vm.allNotesFolder = allNotes ?? fetchSingle(#Predicate { $0.isAllNotes })
        vm.archiveFolder = archive ?? fetchSingle(#Predicate { $0.isArchive })
    }
    
    private func fetchSingle(_ p: Predicate<NoteContainer>) -> NoteContainer? {
        do {
            return try ctx.fetch(FetchDescriptor(predicate: p)).first
        } catch {
            logger.error("Failed to fetch system folder: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func reconcile(
        match: Predicate<NoteContainer>,
    ) throws -> NoteContainer? {
        var candidates = try ctx.fetch(
            FetchDescriptor<NoteContainer>(predicate: match)
        )
        guard !candidates.isEmpty else { return nil }
        
        var repairedSystemFolderColor = false
        for candidate in candidates {
            if candidate.isSystemFolder && candidate.colorRGBA != 0xFF26B9FF {
                candidate.colorRGBA = 0xFF26B9FF
                repairedSystemFolderColor = true
            }
        }
        if repairedSystemFolderColor {
            try ctx.save()
        }
        
        guard candidates.count > 1 else { return nil }
        
        logger.info("System folder duplicate found. Reconciling.")

        guard let canonical = chooseCanonical(from: candidates) else {
            throw SystemFolderReconcilerError.missingCanonicalSystemFolder
        }

        candidates.removeAll {
            $0.persistentModelID == canonical.persistentModelID
        }

        for dup in candidates {
            let dupNotes = Array(dup.notes)
            if dup.isStarred {
                for n in dupNotes { n.starredFolder = canonical }
            } else {
                for n in dupNotes { n.folder = canonical }
            }
            

            if let sel = vm.selectedContainer,
               sel.persistentModelID == dup.persistentModelID {
                vm.selectedContainer = canonical
            }
            ctx.delete(dup)
        }

        try ctx.save()
        
        return canonical
    }

    private func chooseCanonical(from containers: [NoteContainer])
        -> NoteContainer?
    {
        containers.max { lhs, rhs in
            let lhsCount = lhs.notes.count
            let rhsCount = rhs.notes.count
            if lhsCount != rhsCount {
                return lhsCount < rhsCount
            }
            return lhs.persistentModelID.hashValue > rhs.persistentModelID.hashValue
        }
    }
}
