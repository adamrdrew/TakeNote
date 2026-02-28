//
//  NoteEditor.swift
//  TakeNote
//
//  Created by Adam Drew on 8/3/25.
//

import CodeEditorView
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

extension FocusedValues {
    @Entry var togglePreview: (() -> Void)?
    @Entry var doMagicFormat: (() -> Void)?
    @Entry var textIsSelected: Bool?
    @Entry var showAssistantPopover: (() -> Void)?
    @Entry var showBacklinks: (() -> Void)?
    @Entry var openNoteHasBacklinks: Bool?
}

struct EditorCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }
}

struct MarkdownShortcutBar: View {
    let insert: (String) -> Void
    var body: some View {
        HStack(spacing: 12) {
            Spacer()
            Button("#") { insert("#") }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))

            Button("*") { insert("*") }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))

            Button("1.") { insert("1. ") }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))

            Button("```") { insert("```\n\n```") }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16.0))

            Button(action: { insert("[ ](  )") }) {
                Text(verbatim: "[]()")
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16.0))

            Button(action: { insert("`") }) {
                Text(verbatim: "`")
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16.0))
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect()
    }
}

struct NoteEditor: View {
    @Environment(\.modelContext) var modelContext: ModelContext
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var position: CodeEditor.Position = CodeEditor.Position()
    @State private var messages: Set<TextLocated<Message>> = Set()
    @State private var showPreview: Bool = true
    @State private var magicFormatterErrorMessage: String = ""
    @State private var showBackLinks: Bool = false
    @State private var magicFormatterErrorIsPresented: Bool = false
    @State private var isAssistantPopoverPresented: Bool = false
    @State private var openNoteHasBacklinks: Bool = false

    @State private var magicFormatter = MagicFormatter()
    @State private var selectedPhotoItem: PhotosPickerItem?

    #if os(iOS)
        @State private var showNoImageInClipboardAlert: Bool = false
    #endif

    @FocusState var isInputActive: Bool
    @Binding var openNote: Note?

    #if os(macOS)
        let toolbarPosition = ToolbarItemPlacement.secondaryAction
    #endif
    #if os(iOS) || os(visionOS)
        let toolbarPosition = ToolbarItemPlacement.automatic
    #endif

    var hardwareKeyboardConnected: Bool {
        return GCKeyboard.coalesced != nil
    }

    let logger = Logger(
        subsystem: "com.adamdrew.takenote",
        category: "NoteEditor"
    )

    func togglePreview() {
        showPreview.toggle()
        isInputActive = !showPreview
        if showPreview && openNote != nil {
            Task { await openNote?.generateSummary() }
        }
    }

    func showBacklinks() {
        showBackLinks.toggle()
    }

    func showAssistantPopover() {
        isAssistantPopoverPresented = true
    }

    private func clamp(_ r: NSRange, toLength n: Int) -> NSRange {
        let lower = max(0, min(r.location, n))
        let upper = max(lower, min(r.location + r.length, n))
        return NSRange(location: lower, length: upper - lower)
    }

    func doMagicFormat() {
        if magicFormatter.formatterIsBusy { return }
        if openNote == nil { return }
        if openNote!.content.isEmpty { return }
        Task {
            let result = await magicFormatter.magicFormat(
                openNote!.content
            )
            if result.wasCancelled {
                return
            }
            if !result.didSucceed {
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage = result.formattedText
                return
            }
            let currentContentHash = magicFormatter.hashFor(openNote!.content)
            if currentContentHash != result.inputHash {
                logger.critical(
                    "Mismatch between MagicFormat input and current note content."
                )
                magicFormatterErrorIsPresented = true
                magicFormatterErrorMessage =
                    "Mismatch between MagicFormat input and current note content."
                return
            }
            openNote!.setContent(result.formattedText)
            return
        }

    }

    private func insertAtCaret(_ s: String) {
        guard let note = openNote else { return }
        let ns = note.content as NSString
        let range =
            position.selections.first ?? NSRange(location: ns.length, length: 0)
        let clamped = clamp(range, toLength: ns.length)

        var new = note.content
        if let r = Range(clamped, in: new) {
            new.replaceSubrange(r, with: s)
            note.setContent(new)
            // place caret after the inserted text
            let newLoc = clamped.location + (s as NSString).length
            position.selections = [NSRange(location: newLoc, length: 0)]
        }
    }

    private static let maxImageDimension: CGFloat = 2048

    private func insertImage(data: Data) {
        let (downsizedData, mimeType) = Self.downsize(imageData: data)
        let newImage = NoteImage(imageData: downsizedData, mimeType: mimeType)
        modelContext.insert(newImage)
        try? modelContext.save()
        let markdownString = "![image](takenote://image/\(newImage.imageUUID.uuidString))"
        insertAtCaret(markdownString)
        logger.info("Inserted image with UUID \(newImage.imageUUID.uuidString), mimeType: \(mimeType)")
    }

    #if os(iOS)
        private func pasteImageFromClipboard() {
            guard !showPreview else { return }
            guard UIPasteboard.general.hasImages, let image = UIPasteboard.general.image,
                let data = image.jpegData(compressionQuality: 1.0)
            else {
                showNoImageInClipboardAlert = true
                return
            }
            insertImage(data: data)
            logger.info("Inserted image from clipboard via paste button")
        }
    #endif

    #if os(macOS)
        @discardableResult
        private func pasteImageFromMacOSClipboard() -> Bool {
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
            logger.info("Inserted image from macOS clipboard via Cmd+V")
            return true
        }
    #endif

    /// Downsizes image data so the longest dimension is at most 2048px.
    /// Returns the downsized data and its MIME type.
    private static func downsize(imageData: Data) -> (Data, String) {
        let maxDim = maxImageDimension
        #if os(iOS) || os(visionOS)
            guard let image = UIImage(data: imageData) else {
                return (imageData, "image/jpeg")
            }
            let originalSize = image.size
            let longestSide = max(originalSize.width, originalSize.height)
            guard longestSide > maxDim else {
                // No downscaling needed; still re-encode as JPEG
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
                // No downscaling needed; still re-encode as JPEG
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
            let srcRect = CGRect(origin: .zero, size: originalSize)
            let destRect = CGRect(origin: .zero, size: newSize)
            NSGraphicsContext.current?.cgContext.draw(cgImage, in: destRect)
            _ = srcRect  // suppress unused warning
            NSGraphicsContext.restoreGraphicsState()
            if let jpegData = rep.representation(
                using: .jpeg, properties: [.compressionFactor: 0.85]
            ) {
                return (jpegData, "image/jpeg")
            }
            return (imageData, "image/jpeg")
        #endif
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
        return selectedText.isEmpty == false
    }

    @MainActor
    func assistantSelectionReplacement(_ replacement: String) {
        guard let note = openNote else { return }
        guard let nsRange = position.selections.first else { return }
        guard let swiftRange = Range(nsRange, in: note.content) else { return }

        var s = note.content
        s.replaceSubrange(swiftRange, with: replacement)
        note.setContent(s)

        // place caret after the inserted text
        let newLoc = nsRange.location + (replacement as NSString).length
        position.selections = [NSRange(location: newLoc, length: 0)]
    }

    fileprivate func setShowBacklinks() {
        if let on = openNote {
            openNoteHasBacklinks = NoteLinkManager(
                modelContext: modelContext
            ).notesLinkToDestination(on)
        }
    }

    var body: some View {
        if let note = openNote {
            @Bindable var formatter = magicFormatter
            ZStack {
                if !showPreview {
                    GeometryReader { geometry in

                        CodeEditor(
                            text: Binding(
                                get: { note.content },
                                set: {
                                    // Direct assignment intentional: setContent() triggers WidgetCenter.reloadAllTimelines()
                                    // on every call, which would be excessive per-keystroke. Widget reload and summary
                                    // generation happen on note deselection in NoteList.onChange instead.
                                    openNote?.content = $0
                                    openNote?.updatedDate = Date()
                                }
                            ),
                            position: $position,
                            messages: $messages,
                            language: .markdown(),
                            layout: CodeEditor.LayoutConfiguration(
                                showMinimap: false,
                                wrapText: true
                            )
                        )
                        #if os(macOS)
                            .onExitCommand(perform: {
                                withAnimation {
                                    showPreview.toggle()
                                }
                            })
                        #endif
                        #if os(iOS)
                            .modifier(EditorCard())
                        #endif
                        .disabled(magicFormatter.formatterIsBusy)
                        .frame(height: geometry.size.height)
                        .focused($isInputActive)
                        .environment(
                            \.codeEditorTheme,
                            colorScheme == .dark
                                ? Theme.defaultDark : Theme.defaultLight
                        )
                    }
                }
                if showPreview {
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
                                showPreview.toggle()
                            })
                        #endif
                        .onTapGesture {
                            withAnimation {
                                togglePreview()
                            }
                        }
                    }
                }

            }
            .dropDestination(for: Data.self) { items, _ in
                guard !showPreview else { return false }
                var inserted = false
                for item in items {
                    // Validate that the dropped data is image data before inserting
                    #if os(iOS) || os(visionOS)
                        guard UIImage(data: item) != nil else { continue }
                    #elseif os(macOS)
                        guard NSImage(data: item) != nil else { continue }
                    #endif
                    insertImage(data: item)
                    inserted = true
                }
                return inserted
            }
            #if os(macOS)
                .onKeyPress(.init("v"), phases: .down) { keyPress in
                    guard keyPress.modifiers.contains(.command) else { return .ignored }
                    guard !showPreview else { return .ignored }
                    if pasteImageFromMacOSClipboard() {
                        return .handled
                    }
                    return .ignored
                }
            #endif
            .onChange(of: openNote?.id) { _, _ in
                showPreview = true
                setShowBacklinks()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            insertImage(data: data)
                        }
                    }
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }

            .onAppear {
                setShowBacklinks()
            }
            #if os(iOS)
                .alert("No image in clipboard", isPresented: $showNoImageInClipboardAlert) {
                    Button("OK", role: .cancel) {}
                }
            #endif
            .sheet(isPresented: $formatter.formatterIsBusy) {
                VStack {
                    AIMessage(message: "Magic Format", font: .largeTitle)
                        .padding()
                    Button("Cancel", role: .cancel) {
                        magicFormatter.cancel()
                    }
                    .padding()
                }
            }

            .alert(
                magicFormatterErrorMessage,
                isPresented: $magicFormatterErrorIsPresented
            ) {

                Button("OK") {
                    magicFormatterErrorIsPresented = false
                }
            }
            #if os(iOS)
                .safeAreaInset(edge: .bottom) {
                    if isInputActive && !showPreview
                        && !hardwareKeyboardConnected
                    {
                        MarkdownShortcutBar(insert: insertAtCaret)
                        .transition(
                            .move(edge: .bottom).combined(
                                with: .opacity
                            )
                        )
                    }
                }
                .safeAreaPadding(
                    .bottom,
                    (isInputActive && !showPreview) ? 8 : 0
                )
            #endif
            .toolbar {

                ToolbarItem(placement: toolbarPosition) {
                    Button(action: {
                        withAnimation {
                            togglePreview()
                        }
                    }) {
                        Image(
                            systemName: showPreview
                                ? "eye.slash"
                                : "eye"
                        )
                    }
                    .help(showPreview ? "Hide Preview" : "Show Preview")

                }

                ToolbarItem(placement: toolbarPosition) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Image(systemName: "photo.badge.plus")
                    }
                    .disabled(showPreview)
                    .help("Insert Photo")
                }

                #if os(iOS)
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            pasteImageFromClipboard()
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .disabled(showPreview)
                        .help("Paste Image")
                    }
                #endif

                if openNoteHasBacklinks {
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            showBackLinks.toggle()
                        }) {
                            Image(
                                systemName: "link"
                            )
                        }
                        .help("Backlinks")
                        .popover(
                            isPresented: $showBackLinks,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .bottom
                        ) {
                            BackLinks()
                        }
                    }
                }

                if magicFormatter.isAvailable {
                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            doMagicFormat()
                        }) {
                            Image(
                                systemName: "wand.and.sparkles"
                            )
                        }
                        .disabled(magicFormatter.formatterIsBusy)
                        .help("Magic Format")
                    }

                }

                if textIsSelected {

                    ToolbarItem(placement: toolbarPosition) {
                        Button(action: {
                            isAssistantPopoverPresented.toggle()
                        }) {
                            Image(
                                systemName: "apple.intelligence"
                            )
                        }
                        .help("Magic Assistant")
                        .popover(
                            isPresented: $isAssistantPopoverPresented,
                            attachmentAnchor: .point(.center),
                            arrowEdge: .bottom
                        ) {
                            ChatWindow(
                                context: selectedText,
                                instructions: MAGIC_ASSISTANT_PROMPT,
                                prompt: "USER_REQUEST:\n",
                                searchEnabled: false,
                                onBotMessageClick:
                                    assistantSelectionReplacement,
                                toolbarVisible: false,
                                useHistory: false,
                                windowTitleText: "Magic Assistant",
                                windowTitleDescription: "Describe how you want this text formatted, and let AI do the work!",
                                chatBoxPlaceholder: "How do you want this formatted?"

                            )
                            .frame(minWidth: 300, minHeight: 400)
                        }

                    }
                }

            }
            .focusedSceneValue(\.togglePreview, togglePreview)
            .focusedSceneValue(\.doMagicFormat, doMagicFormat)
            .focusedSceneValue(\.textIsSelected, textIsSelected)
            .focusedSceneValue(\.showAssistantPopover, showAssistantPopover)
            .focusedSceneValue(\.openNoteHasBacklinks, openNoteHasBacklinks)
            .focusedSceneValue(\.showBacklinks, showBacklinks)

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
