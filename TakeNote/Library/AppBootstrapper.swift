//  AppBootstrapper.swift
//  TakeNote
//
//  All the gnarly boot logic lives here so TakeNoteApp stays tidy.

import CloudKit
import CoreData
import Foundation
import SwiftData
import os

struct AppBootstrapper {
    struct ReconcilerHarness {
        let reconciler: SystemFolderReconciler
        let tokens: [NSObjectProtocol]
    }

    static func makeModelConfiguration(debugStoreURL: @autoclosure () -> URL)
        -> ModelConfiguration
    {
        #if DEBUG
            return ModelConfiguration(url: debugStoreURL())
        #else
            return ModelConfiguration()
        #endif
    }

    // MARK: - DEBUG: CloudKit Dev schema bootstrap (one-time per version)
    #if DEBUG
        static func bootstrapDevSchemaIfNeeded(
            modelTypes: [any PersistentModel.Type],
            storeURL: URL,
            containerID: String,
            userDefaultsKey: String,
            currentVersion: Int,
            logger: Logger
        ) {
            let already = UserDefaults.standard.integer(forKey: userDefaultsKey)
            guard already < currentVersion else {
                logger.debug("CK bootstrap skipped (v\(already)).")
                return
            }

            do {
                try autoreleasepool {
                    // Build a Core Data model from SwiftData schema
                    let schema = Schema(modelTypes)
                    guard
                        let mom = NSManagedObjectModel.makeManagedObjectModel(
                            for: schema
                        )
                    else {
                        throw NSError(
                            domain: "TakeNote.CloudKitInit",
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Failed to synthesize NSManagedObjectModel"
                            ]
                        )
                    }

                    // Describe a persistent store pointing at the SAME file SwiftData will use
                    let desc = NSPersistentStoreDescription(url: storeURL)
                    desc.shouldAddStoreAsynchronously = false
                    desc.cloudKitContainerOptions = .init(
                        containerIdentifier: containerID
                    )

                    // Temporary Core Data container to push Dev schema
                    let temp = NSPersistentCloudKitContainer(
                        name: "TakeNoteCoreData",
                        managedObjectModel: mom
                    )
                    temp.persistentStoreDescriptions = [desc]

                    var loadErr: Error?
                    temp.loadPersistentStores { _, err in loadErr = err }
                    if let loadErr { throw loadErr }

                    try temp.initializeCloudKitSchema()

                    // Cleanly detach the temp store before returning to SwiftData
                    if let store = temp.persistentStoreCoordinator
                        .persistentStores.first
                    {
                        try temp.persistentStoreCoordinator.remove(store)
                    }
                }

                UserDefaults.standard.set(
                    currentVersion,
                    forKey: userDefaultsKey
                )
                logger.debug(
                    "CK Dev schema bootstrap completed (v\(currentVersion))."
                )
            } catch {
                if shouldIgnoreBootstrapError(error) {
                    logger.info(
                        "CK bootstrap skipped due to expected condition: \(String(describing: error))"
                    )
                } else {
                    logger.warning(
                        "CK bootstrap failed: \(String(describing: error))"
                    )
                }
            }
        }

        private static func shouldIgnoreBootstrapError(_ error: Error) -> Bool {
            if let ck = error as? CKError {
                switch ck.code {
                case .networkUnavailable, .networkFailure, .serviceUnavailable,
                    .notAuthenticated, .requestRateLimited, .internalError:
                    return true
                default: break
                }
            }
            let ns = error as NSError
            return ns.domain == NSCocoaErrorDomain
        }
    #endif

    // MARK: - Reconciler wiring
    @MainActor
    static func installReconciler(
        container: ModelContainer,
        vm: TakeNoteVM,
        runOnStartup: Bool = true,
        listenForLocalSaves: Bool = false,  // set true if you really want it
        searchIndexService: SearchIndexService
    ) -> ReconcilerHarness {
        let reconciler = SystemFolderReconciler(ctx: container.mainContext, vm: vm)

        var tokens: [NSObjectProtocol] = []

        // React to CloudKit sync/merges
        tokens.append(
            NotificationCenter.default.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: nil,
                queue: .main
            ) { [weak reconciler] _ in
                Task { @MainActor in
                    try? reconciler?.runOnce()
                    if searchIndexService.canReindexAllNotes() {
                        // Obtain the main context on the main actor to avoid capturing it in the @Sendable closure
                        let ctx = container.mainContext
                        let notes = try? ctx.fetch(FetchDescriptor<Note>())
                        if let n = notes {
                            searchIndexService.reindexAll(n.map { note in (note.uuid, note.content) })
                        }
                    }
                }
            }
        )

        // Optional: react to every local save (usually not needed)
        if listenForLocalSaves {
            tokens.append(
                NotificationCenter.default.addObserver(
                    forName: .NSManagedObjectContextDidSave,
                    object: container.mainContext,
                    queue: .main
                ) { [weak reconciler] _ in
                    Task { @MainActor in try? reconciler?.runOnce() }
                }
            )
        }

        if runOnStartup {
            try? reconciler.runOnce()
        }

        return ReconcilerHarness(reconciler: reconciler, tokens: tokens)
    }
}
