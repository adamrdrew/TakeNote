//
//  TextFile.swift
//  TakeNote
//
//  Created by Adam Drew on 8/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class TextFile: WritableDocument {
    static let writableContentTypes: [UTType] = [.plainText]

    var text = ""

    init(initialText: String = "") {
        text = initialText
    }

    nonisolated func writer(
        configuration: sending DocumentWriteConfiguration
    ) -> sending FileWrapperDocumentWriter<String> {
        FileWrapperDocumentWriter(configuration) { snapshot in
            FileWrapper(regularFileWithContents: Data(snapshot.utf8))
        }
    }

    func snapshot(contentType: UTType) async throws -> sending String {
        text
    }
}
