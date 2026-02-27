//
//  CommandRegistry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/25/25.
//

import os
import SwiftUI
import SwiftData

private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "CommandRegistry")

@Observable
internal final class CommandRegistry {
    private var commands: [PersistentIdentifier: () -> Void] = [:]

    @MainActor
    func registerCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        commands[id] = command
    }

    @MainActor
    func unregisterCommand(
        id: PersistentIdentifier
    ) {
        commands.removeValue(forKey: id)
    }

    @MainActor
    func runCommand(id: PersistentIdentifier) {
        logger.debug("Running command with ID: \(String(describing: id))")
        commands[id]?()
    }

}
