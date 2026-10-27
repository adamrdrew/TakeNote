//
//  NoteEditor.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

@preconcurrency import CodeEditorView
import GameController
import LanguageSupport
import MarkdownUI
import PhotosUI
import SwiftData
import SwiftUI
import os
#if os(iOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@MainActor
@Observable
final class NoteEditorActions {
    var position = CodeEditor.Position()
    var messages: Set<TextLocated<Message>> = []
    var showPreview = true
    var showBackLinks = false
    var magicFormatterErrorMessage: String?
    var isAssistantPopoverPresented = false
    var openNoteHasBacklinks = false
    var magicFormatter = MagicFormatter()

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var openNote: Note?
    @ObservationIgnored private var magicFormatTask: Task<Void, Never>?
    @ObservationIgnored private var summaryTask: Task<Void, Never>?

    static let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteEditor"
    )

    private static let maxImageDimension: CGFloat = 2048

    func update(openNote: Note?, modelContext: ModelContext) {
        if self.openNote?.persistentModelID != openNote?.persistentModelID {
            cancelMagicFormat()
            cancelSummaryGeneration()
        }
        self.openNote = openNote
        self.modelContext = modelContext
        updateBacklinkAvailability()
    }

    func togglePreview() {
        showPreview.toggle()
        if showPreview, let openNote {
            generateSummary(for: openNote)
        }
    }

    func showBacklinks() {
        showBackLinks.toggle()
    }

    func showAssistantPopover() {
        isAssistantPopoverPresented = true
    }

    private func presentMagicFormatterError(_ message: String) {
        magicFormatterErrorMessage = message
    }

    func cancelMagicFormat() {
        magicFormatTask?.cancel()
        magicFormatTask = nil
        magicFormatter.cancel()
    }

    private func generateSummary(for note: Note) {
        summaryTask?.cancel()
        summaryTask = Task {
            await note.generateSummary()
        }
    }

    func cancelSummaryGeneration() {
        summaryTask?.cancel()
        summaryTask = nil
    }

    func doMagicFormat() {
        guard !magicFormatter.formatterIsBusy else { return }
        guard let note = openNote, !note.content.isEmpty else { return }
        magicFormatTask?.cancel()
        magicFormatTask = Task {
            let result = await magicFormatter.magicFormat(note.content)
            guard !Task.isCancelled else { return }
            if result.wasCancelled {
                return
            }
            if !result.didSucceed {
                presentMagicFormatterError(result.formattedText)
                return
            }
            let currentContentHash = magicFormatter.hashFor(note.content)
            if currentContentHash != result.inputHash {
                Self.logger.critical(
                    "Mismatch between MagicFormat input and current note content."
                )
                presentMagicFormatterError(
                    String(
                        localized: "Mismatch between MagicFormat input and current note content.",
                        comment: "Magic Format error shown when note content changes while formatting is in progress."
                    )
                )
                return
            }
            note.setContent(result.formattedText)
        }
    }

    var selectedText: String {
        guard
            let content = openNote?.content,
            !content.isEmpty,
            let raw = position.selections.first
        else { return "" }

        let ns = content as NSString
        let clamped = clamp(raw, toLength: ns.length)
        return ns.substring(with: clamped)
    }

    var textIsSelected: Bool {
        selectedText.isEmpty == false
    }

    func assistantSelectionReplacement(_ replacement: String) {
        guard let note = openNote else { return }
        guard let nsRange = position.selections.first else { return }
        guard let swiftRange = Range(nsRange, in: note.content) else { return }

        var content = note.content
        content.replaceSubrange(swiftRange, with: replacement)
        note.setContent(content)

        let newLoc = nsRange.location + (replacement as NSString).length
        position.selections = [NSRange(location: newLoc, length: 0)]
    }

    func insertAtCaret(_ string: String) {
        guard let note = openNote else { return }
        let ns = note.content as NSString
        let range =
            position.selections.first ?? NSRange(location: ns.length, length: 0)
        let clamped = clamp(range, toLength: ns.length)

        var content = note.content
        if let swiftRange = Range(clamped, in: content) {
            content.replaceSubrange(swiftRange, with: string)
            note.setContent(content)
            let newLoc = clamped.location + (string as NSString).length
            position.selections = [NSRange(location: newLoc, length: 0)]
        }
    }

    func insertImage(data: Data) {
        guard let modelContext else { return }
        let (downsizedData, mimeType) = Self.downsize(imageData: data)
        let newImage = NoteImage(imageData: downsizedData, mimeType: mimeType)
        modelContext.insert(newImage)
        do {
            try modelContext.save()
        } catch {
            presentMagicFormatterError(error.localizedDescription)
            return
        }
        let markdownString = "![image](takenote://image/\(newImage.imageUUID.uuidString))"
        insertAtCaret(markdownString)
        Self.logger.info("Inserted image with UUID \(newImage.imageUUID.uuidString), mimeType: \(mimeType)")
    }

    func updateBacklinkAvailability() {
        guard let modelContext, let openNote else {
            openNoteHasBacklinks = false
            return
        }
        openNoteHasBacklinks = NoteLinkManager(
            modelContext: modelContext
        ).notesLinkToDestination(openNote)
    }

    private func clamp(_ range: NSRange, toLength length: Int) -> NSRange {
        let lower = max(0, min(range.location, length))
        let upper = max(lower, min(range.location + range.length, length))
        return NSRange(location: lower, length: upper - lower)
    }

    #if os(macOS)
        @discardableResult
        func pasteImageFromMacOSClipboard() -> Bool {
            guard !showPreview else { return false }
            let pasteboard = NSPasteboard.general
            let availableTypes = pasteboard.types ?? []
            guard availableTypes.contains(.tiff) || availableTypes.contains(.png) else {
                return false
            }
            let rawData =
                pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png)
            guard let data = rawData else { return false }
            guard NSImage(data: data) != nil else { return false }
            insertImage(data: data)
            Self.logger.info("Inserted image from macOS clipboard via Cmd+V")
            return true
        }
    #endif

    private static func downsize(imageData: Data) -> (Data, String) {
        let maxDim = maxImageDimension
        #if os(iOS) || os(visionOS)
            guard let image = UIImage(data: imageData) else {
                return (imageData, "image/jpeg")
            }
            let originalSize = image.size
            let longestSide = max(originalSize.width, originalSize.height)
            guard longestSide > maxDim else {
                if let jpegData = image.jpegData(compressionQuality: 0.85) {
                    return (jpegData, "image/jpeg")
                }
                return (imageData, "image/jpeg")
            }
            let scale = maxDim / longestSide
            let newSize = CGSize(
                width: (originalSize.width * scale).rounded(),
                height: (originalSize.height * scale).rounded()
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            if let jpegData = resizedImage.jpegData(compressionQuality: 0.85) {
                return (jpegData, "image/jpeg")
            }
            return (imageData, "image/jpeg")
        #elseif os(macOS)
            guard let image = NSImage(data: imageData) else {
                return (imageData, "image/jpeg")
            }
            let originalSize = image.size
            let longestSide = max(originalSize.width, originalSize.height)
            guard longestSide > maxDim else {
                let rep = NSBitmapImageRep(data: imageData)
                if let jpegData = rep?.representation(
                    using: .jpeg, properties: [.compressionFactor: 0.85]
                ) {
                    return (jpegData, "image/jpeg")
                }
                return (imageData, "image/jpeg")
            }
            let scale = maxDim / longestSide
            let newSize = CGSize(
                width: (originalSize.width * scale).rounded(),
                height: (originalSize.height * scale).rounded()
            )
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return (imageData, "image/jpeg")
            }
            let newRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(newSize.width),
                pixelsHigh: Int(newSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
            guard let rep = newRep else {
                return (imageData, "image/jpeg")
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            let destRect = CGRect(origin: .zero, size: newSize)
            NSGraphicsContext.current?.cgContext.draw(cgImage, in: destRect)
            NSGraphicsContext.restoreGraphicsState()
            if let jpegData = rep.representation(
                using: .jpeg, properties: [.compressionFactor: 0.85]
            ) {
                return (jpegData, "image/jpeg")
            }
            return (imageData, "image/jpeg")
        #endif
    }
}

struct EditorCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct MarkdownShortcutSurface: ViewModifier {
    func body(content: Content) -> some View {
        #if os(visionOS)
        content.background(.regularMaterial, in: .rect(cornerRadius: 16))
        #else
        content.glassEffect(in: .rect(cornerRadius: 16))
        #endif
    }
}

struct MarkdownShortcutBar: View {
    let insert: (String) -> Void
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("#") { insert("#") }
                .padding()
                .modifier(MarkdownShortcutSurface())

            Button("*") { insert("*") }
                .padding()
                .modifier(MarkdownShortcutSurface())

            Button("1.") { insert("1. ") }
                .padding()
                .modifier(MarkdownShortcutSurface())

            Button("```") { insert("```\n\n```") }
                .padding()
                .modifier(MarkdownShortcutSurface())

            Button(action: { insert("[ ](  )") }) {
                Text(verbatim: "[]()")
            }
            .padding()
            .modifier(MarkdownShortcutSurface())

            Button(action: { insert("`") }) {
                Text(verbatim: "`")
            }
            .padding()
            .modifier(MarkdownShortcutSurface())

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        #if !os(visionOS)
        .glassEffect()
        #endif
    }
}

struct NoteEditor: View {
    @Environment(\.modelContext) private var modelContext: ModelContext
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var editorActions = NoteEditorActions()
    @State private var selectedPhotoItem: PhotosPickerItem?

    #if os(iOS)
        @State private var showNothingToPasteAlert: Bool = false
    #endif

    @FocusState private var isInputActive: Bool
    @Binding var openNote: Note?

    #if os(macOS)
        let toolbarPosition = ToolbarItemPlacement.secondaryAction
    #endif
    #if os(iOS) || os(visionOS)
        let toolbarPosition = ToolbarItemPlacement.automatic
    #endif

    private var hardwareKeyboardConnected: Bool {
        GCKeyboard.coalesced != nil
    }

    static let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteEditor"
    )

    #if os(iOS)
        private func pasteFromClipboard() {
            guard !editorActions.showPreview else { return }
            let pasteboard = UIPasteboard.general
            if pasteboard.hasImages, let image = pasteboard.image,
                let data = image.jpegData(compressionQuality: 1.0)
            {
                editorActions.insertImage(data: data)
                Self.logger.info("Inserted image from clipboard via paste button")
            } else if pasteboard.hasStrings, let text = pasteboard.string {
                editorActions.insertAtCaret(text)
                Self.logger.info("Inserted text from clipboard via paste button")
            } else {
                showNothingToPasteAlert = true
            }
        }
    #endif

    var body: some View {
        if let note = openNote {
            @Bindable var note = note
            @Bindable var editorActions = editorActions
            @Bindable var formatter = editorActions.magicFormatter
            ZStack {
                if !editorActions.showPreview {
                    GeometryReader { geometry in

                        CodeEditor(
                            text: $note.editorContent,
                            position: $editorActions.position,
                            messages: $editorActions.messages,
                            language: .markdown()
                        )
                        #if os(macOS)
                            .onExitCommand(perform: {
                                withAnimation {
                                    editorActions.showPreview.toggle()
                                }
                            })
                        #endif
                        #if os(iOS)
                            .modifier(EditorCard())
                        #endif
                        .disabled(editorActions.magicFormatter.formatterIsBusy)
                        .frame(height: geometry.size.height)
                        .focused($isInputActive)
                        .environment(
                            \.codeEditorTheme,
                            colorScheme == .dark
                                ? Theme.defaultDark : Theme.defaultLight
                        )
                        .environment(
                            \.codeEditorLayoutConfiguration,
                            CodeEditor.LayoutConfiguration(
                                showMinimap: false,
                                wrapText: true
                            )
                        )
                    }
                }
                if editorActions.showPreview {
                    GeometryReader { geometry in

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {

                                Markdown(note.content)
                                    .markdownImageProvider(
                                        TakeNoteImageProvider(
                                            modelContext: modelContext
                                        )
                                    )
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(24)

                            }
                            .frame(
                                minHeight: geometry.size.height,
                                maxHeight: .infinity,
                                alignment: .top
                            )

                        }
                        #if os(macOS)
                            .onExitCommand(perform: {
                                editorActions.showPreview.toggle()
                            })
                        #endif
                        .onTapGesture {
                            withAnimation {
                                editorActions.togglePreview()
                            }
                        }
                    }
                }

            }
            .dropDestination(
                for: Data.self,
                isEnabled: !editorActions.showPreview
            ) { items, _ in
                for item in items {
                    // Validate that the dropped data is image data before inserting
                    #if os(iOS) || os(visionOS)
                        guard UIImage(data: item) != nil else { continue }
                    #elseif os(macOS)
                        guard NSImage(data: item) != nil else { continue }
                    #endif
                    editorActions.insertImage(data: item)
                }
            }
            .task(id: openNote?.persistentModelID) {
                editorActions.showPreview = true
                editorActions.update(openNote: openNote, modelContext: modelContext)
            }
            .onChange(of: editorActions.showPreview) { _, newValue in
                isInputActive = !newValue
            }
            .task(id: selectedPhotoItem) {
                guard let item = selectedPhotoItem else { return }
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        guard !Task.isCancelled else { return }
                        editorActions.insertImage(data: data)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.error("Failed to load selected photo data: \(error.localizedDescription)")
                }
                guard !Task.isCancelled else { return }
                selectedPhotoItem = nil
            }

            #if os(iOS)
                .alert("Nothing to paste", isPresented: $showNothingToPasteAlert) {
                    Button("OK", role: .cancel) {}
                }
            #endif
            .sheet(isPresented: $formatter.formatterIsBusy) {
                VStack {
                    AIMessage(message: "Magic Format", font: .largeTitle)
                        .padding()
                    Button("Cancel", role: .cancel) {
                        editorActions.cancelMagicFormat()
                    }
                    .padding()
                }
            }
            .onDisappear {
                editorActions.cancelMagicFormat()
                editorActions.cancelSummaryGeneration()
            }

            .alert(
                "Magic Format Failed",
                item: $editorActions.magicFormatterErrorMessage
            ) {
                _ in Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
            #if os(iOS)
                .safeAreaInset(edge: .bottom) {
                    if isInputActive && !editorActions.showPreview
                        && !hardwareKeyboardConnected
                    {
                        MarkdownShortcutBar(insert: editorActions.insertAtCaret)
                        .transition(
                            .move(edge: .bottom).combined(
                                with: .opacity
                            )
                        )
                    }
                }
                .safeAreaPadding(
                    .bottom,
                    (isInputActive && !editorActions.showPreview) ? 8 : 0
                )
            #endif
            .toolbar {

                ToolbarItem(placement: toolbarPosition) {
                    Button(action: {
                        withAnimation {
                            editorActions.togglePreview()
                        }
                    }) {
                        Image(
                            systemName: editorActions.showPreview
                                ? "eye.slash"
                                : "eye"
                        )
                    }
                    .help(editorActions.showPreview ? "Hide Preview" : "Show Preview")

                }
                .visibilityPriority(.takeNotePrimary)

                ToolbarItem(placement: toolbarPosition) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .disabled(editorActions.showPreview)
                    .help("Insert Photo")
                }
                .visibilityPriority(.takeNoteSecondary)

                #if os(iOS)
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            pasteFromClipboard()
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .disabled(editorActions.showPreview)
                        .help("Paste")
                    }
                    .visibilityPriority(.takeNoteSecondary)
                #endif

                if editorActions.openNoteHasBacklinks {
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            editorActions.showBackLinks.toggle()
                        }) {
                            Image(
                                systemName: "link"
                            )
                        }
                        .help("Backlinks")
                        .popover(
                            isPresented: $editorActions.showBackLinks,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .bottom
                        ) {
                            BackLinks()
                        }
                    }
                    .visibilityPriority(.takeNoteSecondary)
                }

                if editorActions.magicFormatter.isAvailable {
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            editorActions.doMagicFormat()
                        }) {
                            Image(
                                systemName: "wand.and.sparkles"
                            )
                        }
                        .disabled(editorActions.magicFormatter.formatterIsBusy)
                        .help("Magic Format")
                    }
                    .visibilityPriority(.takeNotePrimary)

                }

                if editorActions.textIsSelected {

                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            editorActions.isAssistantPopoverPresented.toggle()
                        }) {
                            Image(
                                systemName: "apple.intelligence"
                            )
                        }
                        .help("Magic Assistant")
                        .adaptivePopover(
                            isPresented: $editorActions.isAssistantPopoverPresented,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .bottom
                        ) {
                            ChatWindow(
                                context: editorActions.selectedText,
                                instructions: MAGIC_ASSISTANT_PROMPT,
                                searchEnabled: false,
                                onBotMessageClick:
                                    editorActions.assistantSelectionReplacement,
                                toolbarVisible: false,
                                useHistory: false,
                                windowTitleText: "Magic Assistant",
                                windowTitleDescription: "Describe how you want this text formatted, and let AI do the work!",
                                chatBoxPlaceholder: "How do you want this formatted?"

                            )
                            .frame(minWidth: 400, minHeight: 500)
                        }

                    }
                    .visibilityPriority(.takeNotePrimary)
                }

            }
            .focusedSceneValue(\.noteEditorActions, editorActions)

        } else {
            VStack {
                Spacer()
                Text("No Note Selected")
                    .font(.title)
                    .padding()
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }

    }
}
