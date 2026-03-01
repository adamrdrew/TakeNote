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

    @ViewBuilder
    func makeImage(url: URL?) -> some View {
        if
            let url = url,
            url.scheme == "takenote",
            url.host == "image",
            let uuidString = url.pathComponents.last,
            let uuid = UUID(uuidString: uuidString),
            let data = NoteImageStore.loadImage(uuid: uuid, modelContext: modelContext)
        {
            #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400)
                } else {
                    EmptyView()
                }
            #else
                if let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 400)
                } else {
                    EmptyView()
                }
            #endif
        } else {
            EmptyView()
        }
    }

}
