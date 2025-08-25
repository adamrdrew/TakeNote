//
//  CommandRegistry.swift
//  TakeNote
//
//  Created by Adam Drew on 8/25/25.
//

import SwiftUI
import SwiftData

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
        print("CommandRegistry: Running Command with ID: \(id)")
        commands[id]?()
    }

}
