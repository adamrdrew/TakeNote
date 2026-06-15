//  AppBootstrapper.swift
//  TakeNote
//
//  App startup and persistence bootstrap helpers.

import CloudKit
import CoreData
import Foundation
import SwiftData
import os

struct AppBootstrapper {
    private enum BootstrapError: LocalizedError {
        case modelSynthesisFailed

        var errorDescription: String? {
            switch self {
            case .modelSynthesisFailed:
                String(
                    localized: "Failed to synthesize NSManagedObjectModel.",
                    comment: "Debug startup error shown when SwiftData cannot produce the Core Data model used for CloudKit schema bootstrap."
                )
            }
        }
    }

    @MainActor
    final class ReconcilerHarness {
        let reconciler: SystemFolderReconciler
        let orphanRecovery: OrphanRecoveryService
        private let container: ModelContainer
        private let searchIndexService: SearchIndexService
        private let logger: Logger
        private var observerTasks: [Task<Void, Never>] = []

        init(
            reconciler: SystemFolderReconciler,
            orphanRecovery: OrphanRecoveryService,
            container: ModelContainer,
            searchIndexService: SearchIndexService,
            logger: Logger
        ) {
            self.reconciler = reconciler
            self.orphanRecovery = orphanRecovery
            self.container = container
            self.searchIndexService = searchIndexService
            self.logger = logger
        }

        func observeRemoteChanges() {
            observerTasks.append(
                Task { @MainActor [weak self] in
                    let notifications = NotificationCenter.default.notifications(
                        named: .NSPersistentStoreRemoteChange
                    )
                    for await _ in notifications {
                        guard !Task.isCancelled else { return }
                        self?.handleRemoteChange()
                    }
                }
            )
        }

        func observeLocalSaves() {
            observerTasks.append(
                Task { @MainActor [weak self] in
                    let notifications = NotificationCenter.default.notifications(
                        named: .NSManagedObjectContextDidSave
                    )
                    for await _ in notifications {
                        guard !Task.isCancelled else { return }
                        guard let self else { return }
                        handleLocalSave()
                    }
                }
            )
        }

        func startStartupReindex() {
            observerTasks.append(
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    logger.info("RAG search startup reindex triggered.")
                    do {
                        try reindexAllSearchableNotes()
                    } catch {
                        logger.error("Startup search reindex fetch failed: \(error.localizedDescription)")
                    }
                }
            )
        }

        private func handleRemoteChange() {
            do {
                try reconciler.runOnce()
                try orphanRecovery.sweep()
                try reindexAllSearchableNotes()
            } catch {
                logger.error("Remote-change reconciliation failed: \(error.localizedDescription)")
            }
        }

        private func handleLocalSave() {
            do {
                try reconciler.runOnce()
            } catch {
                logger.error("Local-save reconciliation failed: \(error.localizedDescription)")
            }
        }

        private func reindexAllSearchableNotes() throws {
            let notes = try container.mainContext.fetch(FetchDescriptor<Note>())
            searchIndexService.reindexAll(notes.filter(AppBootstrapper.isIndexable))
        }

        isolated deinit {
            for task in observerTasks {
                task.cancel()
            }
        }
    }

    static func makeModelConfiguration(debugStoreURL: @autoclosure () throws -> URL) throws
        -> ModelConfiguration
    {
        #if DEBUG
            return try ModelConfiguration(url: debugStoreURL())
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
                        throw BootstrapError.modelSynthesisFailed
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
    private static func isIndexable(_ note: Note) -> Bool {
        note.folder?.isTrash != true
            && note.folder?.isBuffer != true
            && note.folder?.isArchive != true
    }

    @MainActor
    static func installReconciler(
        container: ModelContainer,
        vm: TakeNoteVM,
        runOnStartup: Bool = true,
        listenForLocalSaves: Bool = false,  // set true if you really want it
        searchIndexService: SearchIndexService
    ) -> ReconcilerHarness {
        let logger = Logger(subsystem: "com.adamdrew.takenote", category: "AppBootstrapper")
        let reconciler = SystemFolderReconciler(ctx: container.mainContext, vm: vm)
        let orphanRecovery = OrphanRecoveryService(ctx: container.mainContext, vm: vm)

        let harness = ReconcilerHarness(
            reconciler: reconciler,
            orphanRecovery: orphanRecovery,
            container: container,
            searchIndexService: searchIndexService,
            logger: logger
        )

        // React to CloudKit sync/merges
        harness.observeRemoteChanges()

        // Optional: react to every local save (usually not needed)
        if listenForLocalSaves {
            harness.observeLocalSaves()
        }

        if runOnStartup {
            do {
                try reconciler.runOnce()
                try orphanRecovery.sweep()
            } catch {
                logger.error("Startup reconciliation failed: \(error.localizedDescription)")
            }
            harness.startStartupReindex()
        }

        return harness
    }
}
