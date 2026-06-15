//
//  CommandRegistry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/25/25.
//

import Observation
import os
import SwiftData

private let logger = Logger(subsystem: "com.adamdrew.takenote", category: "CommandRegistry")

@MainActor
@Observable
final class CommandRegistry {
    @ObservationIgnored
    private var commands: [PersistentIdentifier: () -> Void] = [:]

    func registerCommand(
        id: PersistentIdentifier,
        command: @escaping () -> Void
    ) {
        commands[id] = command
    }

    func unregisterCommand(
        id: PersistentIdentifier
    ) {
        commands.removeValue(forKey: id)
    }

    func runCommand(id: PersistentIdentifier) {
        logger.debug("Running command with ID: \(String(describing: id))")
        commands[id]?()
    }

}
