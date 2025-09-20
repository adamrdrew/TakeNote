import AppIntents
import CloudKit
import CoreData
import SwiftData
import SwiftUI
import os

// Bump this to get the welcome screen to show for users on next launch
private let onboardingVersionCurrent = 2
private let onboardingVersionKey = "onboarding.version.seen"

#if DEBUG
    // Bump this to get the schema to update, for example if there have been model changes
    private let ckBootstrapVersionCurrent = 8
    private let ckBootstrapVersionKey = "takenote.ck.bootstrap.version"
#endif

@main
struct TakeNoteApp: App {
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false
    @State private var refreshTask: Task<Void, Never>?
    private var reconcilerHarness: AppBootstrapper.ReconcilerHarness?
    var takeNoteVM = TakeNoteVM()

    let container: ModelContainer
    private let search = SearchIndexService()
    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "App"
    )

    private func startActiveRefreshLoop(ctx: ModelContext) {
        // cancel previous loop if any
        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            // iOS will suspend timers when the app is backgrounded; this only runs while active
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000) // 10 min
                SnapshotController.takeSnapshot(modelContext: ctx)
            }
        }
    }
    
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
            let tempBootstrapURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "CKBootstrap-\(UUID().uuidString).sqlite"
                )
            AppBootstrapper.bootstrapDevSchemaIfNeeded(
                modelTypes: [Note.self, NoteContainer.self, NoteLink.self],
                storeURL: tempBootstrapURL,
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

        // Capture values in locals to avoid capturing `self` in escaping closures
        let modelContainer = container
        let viewModel = takeNoteVM

        // Got this from here: https://www.malcolmhall.com/2024/07/22/how-to-use-swiftdata-with-appintents/
        let asyncModelContainerDep: @Sendable () async -> ModelContainer = {
            @MainActor in
            return modelContainer
        }
        AppDependencyManager.shared.add(
            key: "ModelContainer",
            dependency: asyncModelContainerDep
        )
        let asyncViewModelDep: @Sendable () async -> TakeNoteVM = {
            @MainActor in
            return viewModel
        }
        AppDependencyManager.shared.add(
            key: "TakeNoteVM",
            dependency: asyncViewModelDep
        )

        // 4) Reconciler + observers (remote changes only by default)

        reconcilerHarness = AppBootstrapper.installReconciler(
            container: container,
            vm: takeNoteVM,
            runOnStartup: true,
            listenForLocalSaves: true,
            searchIndexService: search
        )

    }

    private var MainAppWindow: some View {
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

            .focusedSceneValue(takeNoteVM)
            .focusedSceneValue(search)
            .environment(takeNoteVM)
            .environment(search)
    }

    /// We need this helper and MainAppWindow because we want Window on macOS and WindowGroup everywhere else,
    /// because other platforms don't support Window. If we use WindowGroup on macOS we get all kinds of undesired effects.
    /// So we kind of have to jump through hoops to get the per-platform setup we want without duplication
    private var MainSceneCore: some Scene {
        #if os(macOS)
            Window("TakeNote", id: "main-window") {
                MainAppWindow
            }

            .windowToolbarStyle(.automatic)
        #else
            WindowGroup(id: "main-window") {
                MainAppWindow
            }
        #endif
    }

    var body: some Scene {
        MainSceneCore
            .commands {
                CommandGroup(replacing: .newItem) { EmptyView() }
                FileCommands()
                EditCommands()
                WindowCommands()
                ViewCommands()
            }
            .modelContainer(container)
            .onChange(of: scenePhase) { _, newPhase in
                Task { @MainActor in
                    let ctx = ModelContext(container)
                    switch newPhase {
                    case .active:
                        // write at launch/foreground
                        SnapshotController.takeSnapshot(modelContext: ctx)
                        // kick off a lightweight refresh loop while active
                        startActiveRefreshLoop(ctx: ctx)
                    case .inactive, .background:
                        // write a final snapshot on background
                        SnapshotController.takeSnapshot(modelContext: ctx)
                    // loop auto-cancels when scene goes inactive/background
                    @unknown default:
                        break
                    }
                }
            }
            .handlesExternalEvents(
                matching: ["takenote://"]
            )

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            NoteEditorWindow(noteID: noteID)
                .environment(search)
                .environment(TakeNoteVM())  // intentional per your comment
        }
        .modelContainer(container)

        WindowGroup("TakeNote - AI Chat", id: "chat-window") {
            if chatFeatureFlagEnabled {
                ChatWindow()
                    .environment(search)
                    .environment(TakeNoteVM())  // intentional
            } else {
                Text(
                    "You shouldn't be seeing this. Please report the bug to adamrdrew@live.com"
                )
            }
        }
        .modelContainer(container)
    }
}
