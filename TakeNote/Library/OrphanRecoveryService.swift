//
//  OrphanRecoveryService.swift
//  TakeNote
//

import os
import SwiftData
import SwiftUI

@MainActor
final class OrphanRecoveryService {
    private let ctx: ModelContext
    private let vm: TakeNoteVM
    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "OrphanRecoveryService"
    )

    init(ctx: ModelContext, vm: TakeNoteVM) {
        self.ctx = ctx
        self.vm = vm
    }

    func sweep() throws {
        let orphans = try ctx.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.folder == nil })
        )
        guard !orphans.isEmpty else { return }

        logger.warning("Found \(orphans.count) orphaned note(s). Recovering.")

        let folder = try recoveryFolder()
        for note in orphans {
            note.folder = folder
        }
        try ctx.save()

        vm.orphanRecoveryFolderName = folder.name
        vm.orphanRecoveryAlertVisible = true

        logger.info("Moved \(orphans.count) orphaned note(s) to '\(folder.name)'.")
    }

    private func recoveryFolder() throws -> NoteContainer {
        let todayName = "Recovered Notes \(Self.formattedDate())"

        let existing = try ctx.fetch(
            FetchDescriptor<NoteContainer>(
                predicate: #Predicate { $0.name == todayName }
            )
        )
        if let folder = existing.first { return folder }

        let folder = NoteContainer(
            canBeDeleted: true,
            isTrash: false,
            isInbox: false,
            name: todayName,
            symbol: "exclamationmark.triangle"
        )
        folder.colorRGBA = 0xFF0000FF // red
        ctx.insert(folder)
        return folder
    }

    private static func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM/yy"
        return fmt.string(from: Date())
    }
}
