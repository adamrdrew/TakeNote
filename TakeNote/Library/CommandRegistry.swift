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
    var commands: [PersistentIdentifier: () -> Void] = [:]

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
        print("CommandRegistry: Running Command with ID: \(id)")
        commands[id]?()
    }

}
