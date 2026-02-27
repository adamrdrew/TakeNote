//
//  TakeNoteImageProvider.swift
//  TakeNote
//

import MarkdownUI
import SwiftData
import SwiftUI

/// Resolves takenote://image/<UUID> URLs to inline images in MarkdownUI preview mode.
struct TakeNoteImageProvider: ImageProvider {

    let modelContext: ModelContext

    func makeImage(url: URL?) -> some View {
        guard
            let url = url,
            url.scheme == "takenote",
            url.host == "image",
            let uuidString = url.pathComponents.last,
            let uuid = UUID(uuidString: uuidString),
            let data = NoteImageStore.loadImage(uuid: uuid, modelContext: modelContext)
        else {
            return AnyView(EmptyView())
        }

        #if os(macOS)
            if let nsImage = NSImage(data: data) {
                return AnyView(
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400)
                )
            }
        #else
            if let uiImage = UIImage(data: data) {
                return AnyView(
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400)
                )
            }
        #endif

        return AnyView(EmptyView())
    }

}
