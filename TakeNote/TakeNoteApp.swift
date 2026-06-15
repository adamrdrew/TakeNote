import AppIntents
import CloudKit
import CoreData
import SwiftData
import SwiftUI
import os

// Bump this to get the welcome screen to show for users on next launch
private let onboardingVersionCurrent = 5
private let onboardingVersionKey = "onboarding.version.seen"

#if DEBUG
    // Bump this to get the schema to update, for example if there have been model changes
    private let ckBootstrapVersionCurrent = 11
    private let ckBootstrapVersionKey = "takenote.ck.bootstrap.version"
#endif

private enum AppStartupError: LocalizedError {
    case applicationSupportDirectory(String)
    case debugStoreDirectory(String)
    case modelContainer(String)

    var errorDescription: String? {
        switch self {
        case .applicationSupportDirectory(let message):
            String(
                localized: "TakeNote could not resolve the Application Support directory: \(message)",
                comment: "Startup error; the variable is the underlying system error message."
            )
        case .debugStoreDirectory(let message):
            String(
                localized: "TakeNote could not create its debug store directory: \(message)",
                comment: "Startup error in debug builds; the variable is the underlying system error message."
            )
        case .modelContainer(let message):
            String(
                localized: "TakeNote could not initialize its database: \(message)",
                comment: "Startup error; the variable is the underlying database initialization error message."
            )
        }
    }
}

@main
struct TakeNoteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(onboardingVersionKey) private var onboardingVersionSeen: Int = 0
    @State private var showOnboarding = false
    @State private var refreshTask: Task<Void, Never>?
    private var reconcilerHarness: AppBootstrapper.ReconcilerHarness?
    var takeNoteVM = TakeNoteVM()

    let container: ModelContainer?
    private let startupError: AppStartupError?
    private let search = SearchIndexService()
    private let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "App"
    )

    private func startActiveRefreshLoop(ctx: ModelContext) {
        stopActiveRefreshLoop()
        refreshTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(10 * 60))
                } catch {
                    return
                }
                SnapshotController.takeSnapshot(modelContext: ctx)
            }
        }
    }

    private func stopActiveRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    static func debugStoreURL() throws -> URL {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw AppStartupError.applicationSupportDirectory(error.localizedDescription)
        }
        let dir = base.appendingPathComponent("TakeNoteDev", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        } catch {
            throw AppStartupError.debugStoreDirectory(error.localizedDescription)
        }
        return dir.appendingPathComponent("TakeNote.sqlite")
    }

    init() {
        do {
            let config = try AppBootstrapper.makeModelConfiguration(
                debugStoreURL: try Self.debugStoreURL()
            )

            #if DEBUG
                let tempBootstrapURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        "CKBootstrap-\(UUID().uuidString).sqlite"
                    )
                AppBootstrapper.bootstrapDevSchemaIfNeeded(
                    modelTypes: [Note.self, NoteContainer.self, NoteLink.self, NoteImage.self],
                    storeURL: tempBootstrapURL,
                    containerID: "iCloud.com.adamdrew.takenote",
                    userDefaultsKey: ckBootstrapVersionKey,
                    currentVersion: ckBootstrapVersionCurrent,
                    logger: logger
                )
            #endif

            let modelContainer = try ModelContainer(
                for: Note.self,
                NoteContainer.self,
                NoteLink.self,
                NoteImage.self,
                configurations: config
            )

            container = modelContainer
            startupError = nil

            let viewModel = takeNoteVM

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
            let searchService = search
            let asyncSearchDep: @Sendable () async -> SearchIndexService = {
                @MainActor in
                return searchService
            }
            AppDependencyManager.shared.add(
                key: "SearchIndexService",
                dependency: asyncSearchDep
            )
            TakeNoteShortcuts.updateAppShortcutParameters()

            reconcilerHarness = AppBootstrapper.installReconciler(
                container: modelContainer,
                vm: takeNoteVM,
                runOnStartup: true,
                listenForLocalSaves: true,
                searchIndexService: search
            )
        } catch {
            container = nil
            if let startupError = error as? AppStartupError {
                self.startupError = startupError
            } else {
                startupError = .modelContainer(error.localizedDescription)
            }
            logger.critical("TakeNote startup failed: \(error.localizedDescription)")
        }
    }

    /// Uses a single app scene definition while preserving macOS's single-window behavior.
    private var mainSceneCore: some Scene {
        #if os(macOS)
            Window("TakeNote", id: "main-window") {
                MainAppWindowContent(
                    container: container,
                    startupError: startupError,
                    showOnboarding: $showOnboarding,
                    onboardingVersionSeen: $onboardingVersionSeen,
                    takeNoteVM: takeNoteVM,
                    search: search,
                    onboardingVersionCurrent: onboardingVersionCurrent
                )
            }

            .windowToolbarStyle(.automatic)
            .windowResizability(.contentMinSize)
        #else
            WindowGroup(id: "main-window") {
                MainAppWindowContent(
                    container: container,
                    startupError: startupError,
                    showOnboarding: $showOnboarding,
                    onboardingVersionSeen: $onboardingVersionSeen,
                    takeNoteVM: takeNoteVM,
                    search: search,
                    onboardingVersionCurrent: onboardingVersionCurrent
                )
            }
        #endif
    }

    var body: some Scene {
        mainSceneCore
            .commands {
                CommandGroup(replacing: .newItem) { EmptyView() }
                FileCommands()
                EditCommands()
                WindowCommands()
                ViewCommands()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard let container else { return }
                let ctx = ModelContext(container)
                switch newPhase {
                case .active:
                    SnapshotController.takeSnapshot(modelContext: ctx)
                    startActiveRefreshLoop(ctx: ctx)
                case .inactive, .background:
                    stopActiveRefreshLoop()
                    SnapshotController.takeSnapshot(modelContext: ctx)
                    if let openNote = takeNoteVM.openNote {
                        search.reindex(note: openNote)
                    }
                @unknown default:
                    break
                }
            }
            .handlesExternalEvents(
                matching: ["takenote://"]
            )

        WindowGroup(id: "note-editor-window", for: NoteIDWrapper.self) {
            noteID in
            if let container {
                NoteEditorWindow(noteID: noteID)
                    .environment(search)
                    .environment(TakeNoteVM())
                    .modelContainer(container)
            } else {
                StartupFailureView(error: startupError)
            }
        }

        WindowGroup("TakeNote - Magic Chat", id: "chat-window") {
            if let container {
                if chatFeatureFlagEnabled {
                    ChatWindow()
                        .environment(search)
                        .environment(TakeNoteVM())
                        .modelContainer(container)
                } else {
                    Text(
                        "You shouldn't be seeing this. Please report the bug to adamrdrew@live.com"
                    )
                    .modelContainer(container)
                }
            } else {
                StartupFailureView(error: startupError)
            }
        }
    }
}

private struct StartupFailureView: View {
    let error: AppStartupError?

    var body: some View {
        ContentUnavailableView {
            Label("TakeNote Could Not Start", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error?.localizedDescription ?? String(localized: "An unknown startup error occurred."))
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 320)
        #endif
    }
}

private struct MainAppWindowContent: View {
    let container: ModelContainer?
    let startupError: AppStartupError?
    @Binding var showOnboarding: Bool
    @Binding var onboardingVersionSeen: Int
    let takeNoteVM: TakeNoteVM
    let search: SearchIndexService
    let onboardingVersionCurrent: Int

    var body: some View {
        if let container {
            MainWindow()
                #if os(macOS)
                .frame(minWidth: 960, minHeight: 600)
                #endif
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
                .modelContainer(container)
        } else {
            StartupFailureView(error: startupError)
        }
    }
}
