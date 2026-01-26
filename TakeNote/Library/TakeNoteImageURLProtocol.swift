//
//  TakeNoteImageURLProtocol.swift
//  TakeNote
//
//  Created by Adam Drew on 9/9/25.
//

import Foundation
import SwiftData

enum TakeNoteImageURLProtocolRegistrar {
    private static var isRegistered = false

    static func registerIfNeeded(container: ModelContainer) {
        guard !isRegistered else { return }
        TakeNoteImageURLProtocol.modelContainer = container
        URLProtocol.registerClass(TakeNoteImageURLProtocol.self)
        isRegistered = true
    }
}

final class TakeNoteImageURLProtocol: URLProtocol {
    static var modelContainer: ModelContainer?

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return url.scheme == "takenote" && url.host == "image"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        guard let uuid = UUID(uuidString: url.lastPathComponent) else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }
        guard let container = Self.modelContainer else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.resourceUnavailable)
            )
            return
        }

        Task { [weak self] @MainActor in
            guard let self else { return }
            let context = ModelContext(container)
            let image = (try? context.fetch(
                FetchDescriptor<NoteImage>(
                    predicate: #Predicate { $0.uuid == uuid }
                )
            ))?.first

            guard let image else {
                self.client?.urlProtocol(
                    self,
                    didFailWithError: URLError(.fileDoesNotExist)
                )
                return
            }

            let response = URLResponse(
                url: url,
                mimeType: image.mimeType,
                expectedContentLength: image.data.count,
                textEncodingName: nil
            )
            self.client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            self.client?.urlProtocol(self, didLoad: image.data)
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
