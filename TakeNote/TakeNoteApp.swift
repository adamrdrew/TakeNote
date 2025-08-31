//
//  TakeNoteApp.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CoreData
import SwiftData
import SwiftUI
import os

private let onboardingVersionCurrent = 1
private let onboardingVersionKey = "onboarding.version.seen"

@main
struct TakeNoteApp: App {
    @Environment(\.modelContext) var modelContext
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false
    @State private var reconciler: SystemFolderReconciler!
    private var tokens: [NSObjectProtocol] = []
    var takeNoteVM = TakeNoteVM()

    let container: ModelContainer
    private var search = SearchIndexService()
    let logger = Logger(subsystem: "com.adamdrew.takenote", category: "App")

    // MARK: - Why this exists
    // CloudKit separates data by *environment* (Development when run from Xcode; Production when via TestFlight/App Store).
    // That protects your *cloud* data.
    //
    // But locally, SwiftData persists to an on-disk SQLite file under your app’s sandbox path.
    // If you use one target / bundle ID for both your “daily use” app and your dev runs,
    // they’ll point at the *same* local database, which is risky during development (schema changes, test data).
    //
    // So, in DEBUG, we point SwiftData at a *different local file* (“TakeNoteDev/TakeNote.sqlite”).
    // This keeps your everyday local data separate from your dev/testing local data.
    //
    // If you later adopt *two targets with different bundle IDs*, you can DELETE this whole function
    // and just use ModelConfiguration() everywhere, because each bundle ID gets a different sandbox automatically.
    static func debugStoreURL() -> URL {
        // Find the per-user Application Support directory:
        let base = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Put dev data in a sibling folder so it never collides with your “real” store:
        let dir = base.appendingPathComponent("TakeNoteDev", isDirectory: true)

        // Make sure the folder exists:
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        // Use a fixed filename inside that directory:
        return dir.appendingPathComponent("TakeNote.sqlite")
    }

    init() {
        do {
            // MARK: 1) Choose where SwiftData will store its *local* database
            // In DEBUG, use the special dev path. In Release (including TestFlight/App Store), use the default path.
            #if DEBUG
                let config = ModelConfiguration(url: Self.debugStoreURL())
            #else
                let config = ModelConfiguration()  // default on-disk store under the app’s sandbox
            #endif

            // MARK: 2) One-time CloudKit Development schema bootstrap (DEBUG only)
            //
            // CloudKit needs a schema (record types/fields) that matches your SwiftData model.
            // SwiftData itself doesn’t expose “create/update schema” APIs, but Core Data does:
            // NSPersistentCloudKitContainer.initializeCloudKitSchema().
            //
            // The trick: create a *temporary* Core Data stack that points to THE SAME FILE URL
            // that SwiftData will use, ask it to initialize the CloudKit schema, then tear it down.
            //
            // You typically run this when:
            //  - First enabling CloudKit, or
            //  - After you change your SwiftData models (properties/relationships).
            //
            // It’s harmless if it runs multiple times, but you don’t need it *every* launch,
            // so feel free to gate it behind a version flag in UserDefaults if you want.
            #if DEBUG
                try autoreleasepool {
                    // Use autoreleasepool so the temporary Core Data container is deallocated
                    // before we create the real SwiftData ModelContainer.
                    // (Avoids “two frameworks syncing the same store at once” overlap.)

                    // Get the exact on-disk location SwiftData will use:
                    let storeURL = config.url

                    // Describe a Core Data store that points to that same file:
                    let desc = NSPersistentStoreDescription(url: storeURL)

                    // Force synchronous load; initializeCloudKitSchema() must happen *after* load finishes:
                    desc.shouldAddStoreAsynchronously = false

                    // Tell Core Data which iCloud container to target:
                    desc.cloudKitContainerOptions = .init(
                        containerIdentifier: "iCloud.com.adamdrew.takenote"  // <-- your container ID
                    )

                    // Build an NSManagedObjectModel from your SwiftData Schema.
                    // (This API is provided by Apple to bridge SwiftData models to Core Data.)
                    let schema = Schema([
                        Note.self, NoteContainer.self, NoteLink.self,
                    ])

                    guard
                        let mom = NSManagedObjectModel.makeManagedObjectModel(
                            for: schema
                        )
                    else {
                        // If this fails, it usually means a model problem (e.g., non-optional relationship,
                        // no inverse, or a SwiftData type wasn’t included in the schema array above).
                        throw NSError(
                            domain: "TakeNote.CloudKitInit",
                            code: 2,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Failed to synthesize NSManagedObjectModel from SwiftData schema"
                            ]
                        )
                    }

                    // Create a temporary Core Data + CloudKit container purely to perform schema init:
                    let temp = NSPersistentCloudKitContainer(
                        name: "TakeNoteCoreData",
                        managedObjectModel: mom
                    )
                    temp.persistentStoreDescriptions = [desc]

                    // Load the store (synchronously, because of desc.shouldAddStoreAsynchronously = false):
                    var loadErr: Error?
                    temp.loadPersistentStores { _, err in loadErr = err }
                    if let loadErr { throw loadErr }

                    // This publishes/updates the *Development* schema for your container based on the model:
                    try temp.initializeCloudKitSchema()

                    // IMPORTANT: remove/unload the temporary Core Data store BEFORE creating the SwiftData container.
                    // This ensures only *one* framework is managing CloudKit syncing (SwiftData) after init.
                    if let store = temp.persistentStoreCoordinator
                        .persistentStores.first
                    {
                        try temp.persistentStoreCoordinator.remove(store)
                    }
                }
            #endif

            // MARK: 3) Create the real SwiftData stack (this is what your app actually uses)
            // Use the *same* model list you used to build the schema above.
            container = try ModelContainer(
                for: Note.self,
                NoteContainer.self,
                NoteLink.self,
                configurations: config
            )
            initSystemFolderReconciler(container)
        } catch {
            // If you land here, the error is almost always model-schema related in DEBUG:
            //  - Relationship missing an inverse
            //  - Relationship not optional (CloudKit requires optional relationships)
            //  - Non-optional scalar without a default value
            //  - Wrong/missing iCloud container entitlement
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    @MainActor
    mutating func initSystemFolderReconciler(_ container: ModelContainer) {
        let ctx = container.mainContext
        let r = SystemFolderReconciler(ctx: ctx, vm: takeNoteVM)
        _reconciler = State(initialValue: r)

        let nc = NotificationCenter.default
        tokens.append(
            nc.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: container.mainContext,
                queue: .main
            ) { [weak r] _ in
                try? r?.runOnce()
            }
        )
        tokens.append(
            nc.addObserver(
                forName: .NSPersistentStoreRemoteChange,
                object: nil,
                queue: .main
            ) { [weak r] _ in
                try? r?.runOnce()
            }
        )

        // First run at startup
        try? r.runOnce()
    }

    var body: some Scene {
        WindowGroup(id: "main-window") {
            MainWindow()
                .sheet(isPresented: $showOnboarding) {
                    WelcomeView {
                        onboardingVersionSeen = onboardingVersionCurrent
                        #if DEBUG
                            onboardingVersionSeen = 0
                        #endif
                        showOnboarding = false
                    }
                }
                .task {
                    showOnboarding =
                        onboardingVersionSeen < onboardingVersionCurrent
                }
                .handlesExternalEvents(
                    preferring: ["takenote://"],
                    allowing: ["*"]
                )
                .focusedSceneValue(takeNoteVM)
                .focusedSceneValue(search)
        }
        .environment(takeNoteVM)
        .environment(search)
        #if os(macOS)
            .windowToolbarStyle(.expanded)
        #endif
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                EmptyView()
            }
            FileCommands()
            EditCommands()
            WindowCommands()
            ViewCommands()
        }
        .modelContainer(container)

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
        }
        .environment(search)
        /// Having different TakeNoteVM instances per window is by design and is not a bug
        .environment(TakeNoteVM())
        .modelContainer(container)

        WindowGroup("TakeNote - AI Chat", id: "chat-window") {
            ChatWindow()
                .environment(search)
        }
        .environment(search)
        /// Having different TakeNoteVM instances per window is by design and is not a bug
        .environment(TakeNoteVM())
        .modelContainer(container)

    }

}
