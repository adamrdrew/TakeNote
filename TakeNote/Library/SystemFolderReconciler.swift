//
//  SystemFolderReconciler.swift
//  TakeNote
//
//  Created by Adam Drew on 8/31/25.
//

import SwiftData
import SwiftUI

@MainActor
final class SystemFolderReconciler {
    private let ctx: ModelContext
    private let vm: TakeNoteVM
    private var isRunning = false

    init(ctx: ModelContext, vm: TakeNoteVM) {
        self.ctx = ctx
        self.vm = vm
    }

    func runOnce() throws {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }   // <— important

        let inbox  = try reconcile(match: #Predicate { $0.isInbox })
        let trash  = try reconcile(match: #Predicate { $0.isTrash })
        let buffer = try reconcile(match: #Predicate { $0.isBuffer })
        let starred = try reconcile(match: #Predicate { $0.isStarred })

        // Even if reconcile() returned nil (because count == 0 or 1),
        // we still want the VM to hold the current canonical (if one exists).
        vm.inboxFolder  = inbox  ?? fetchSingle(#Predicate { $0.isInbox })
        vm.trashFolder  = trash  ?? fetchSingle(#Predicate { $0.isTrash })
        vm.bufferFolder = buffer ?? fetchSingle(#Predicate { $0.isBuffer })
        vm.starredFolder = starred ?? fetchSingle(#Predicate { $0.isStarred })
    }
    
    private func fetchSingle(_ p: Predicate<NoteContainer>) -> NoteContainer? {
        try? ctx.fetch(FetchDescriptor(predicate: p)).first
    }
    
    private func reconcile(
        match: Predicate<NoteContainer>,
    ) throws -> NoteContainer?  {
        var candidates = try ctx.fetch(
            FetchDescriptor<NoteContainer>(predicate: match)
        )
        // No matching folder? bail
        guard !candidates.isEmpty else { return nil }
        // Only one folder? bail
        guard candidates.count  > 1 else { return nil }
        
        print("System folder duplicate found. Reconciling...")


        // Choose canonical
        let canonical = try chooseCanonical(from: candidates)

        // Remove canonical from dupes list
        candidates.removeAll {
            $0.persistentModelID == canonical.persistentModelID
        }

        // Move notes off duplicates, then delete the dupes
        for dup in candidates {
            let dupNotes = Array(dup.notes)       // copy
            for n in dupNotes { n.folder = canonical }

            if let sel = vm.selectedContainer,
               sel.persistentModelID == dup.persistentModelID {   // compare by ID
                vm.selectedContainer = canonical
            }
            ctx.delete(dup)
        }

        try ctx.save()
        
        return canonical
    }

    private func chooseCanonical(from containers: [NoteContainer]) throws
        -> NoteContainer
    {
        // most notes, then lowest ID hash
        return containers.min { a, b in
            let ca = a.notes.count
            let cb = b.notes.count
            if ca != cb { return cb < ca }  // want max; using min with reversed compare
            return a.persistentModelID.hashValue < b.persistentModelID.hashValue
        }!
    }
}
