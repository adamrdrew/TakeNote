import CloudKit
import CoreData
import SwiftData
import SwiftUI
import os

private let onboardingVersionCurrent = 1
private let onboardingVersionKey = "onboarding.version.seen"

#if DEBUG
    private let ckBootstrapVersionCurrent = 1
    private let ckBootstrapVersionKey = "takenote.ck.bootstrap.version"
#endif

@main
struct TakeNoteApp: App {
    @Environment(\.modelContext) var modelContext
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false
    private var reconcilerHarness: AppBootstrapper.ReconcilerHarness?
    var takeNoteVM = TakeNoteVM()

    let container: ModelContainer
    private let search = SearchIndexService()
    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "App"
    )

    static func debugStoreURL() -> URL {
        let base = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("TakeNoteDev", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("TakeNote.sqlite")
    }

    init() {
        // 1) Config (dev/prod)
        let config = AppBootstrapper.makeModelConfiguration(
            debugStoreURL: Self.debugStoreURL()
        )

        // 2) DEBUG-only: initialize CloudKit Dev schema if needed
        #if DEBUG
            AppBootstrapper.bootstrapDevSchemaIfNeeded(
                modelTypes: [Note.self, NoteContainer.self, NoteLink.self],
                storeURL: config.url,
                containerID: "iCloud.com.adamdrew.takenote",
                userDefaultsKey: ckBootstrapVersionKey,
                currentVersion: ckBootstrapVersionCurrent,
                logger: logger
            )
        #endif

        // 3) Real SwiftData container
        do {
            container = try ModelContainer(
                for: Note.self,
                NoteContainer.self,
                NoteLink.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // 4) Reconciler + observers (remote changes only by default)

        reconcilerHarness = AppBootstrapper.installReconciler(
            container: container,
            vm: takeNoteVM,
            runOnStartup: true,
            listenForLocalSaves: true,
            searchIndexService: search
        )

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
        .windowToolbarStyle(.automatic)
        #endif
        .commands {
            CommandGroup(replacing: .newItem) { EmptyView() }
            FileCommands()
            EditCommands()
            WindowCommands()
            ViewCommands()
        }
        .modelContainer(container)

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
                .environment(search)
                .environment(TakeNoteVM())  // intentional per your comment
        }
        .modelContainer(container)

        WindowGroup("TakeNote - AI Chat", id: "chat-window") {
            ChatWindow()
                .environment(search)
                .environment(TakeNoteVM())  // intentional
        }
        .modelContainer(container)
    }
}
