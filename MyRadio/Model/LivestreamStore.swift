//
//  LivestreamStore.swift
//  MyRadio
//
//  Created by Philipp on 19.10.20.
//

import Foundation
import SwiftUI

@MainActor
final class LivestreamStore: ObservableObject {

    init(_ streams: [Livestream]) {
        self.streams = streams
    }

    @Published private(set) var streams: [Livestream]

    // MARK: - Accessors

    func streams(for bu: BusinessUnit) -> [Livestream] {
        streams.filter({ $0.bu == bu })
    }

    func stream(withID streamID: String) -> Livestream? {
        guard let index = streams.firstIndex(where: { $0.id == streamID }) else { return nil }
        return streams[index]
    }

    // MARK: - Mutators

    func removeAll() {
        streams.removeAll()
    }

    func append(streams newStreams: [Livestream]) {
        streams.append(contentsOf: newStreams)
    }

    func update(stream: Livestream) {
        guard let index = streams.firstIndex(where: { $0.id == stream.id }) else {
            fatalError("Streams \(stream) not found.")
        }
        streams[index] = stream
    }

    @discardableResult
    func saveThumbnailData(_ data: Data, for stream: Livestream) -> Livestream {
        guard let index = streams.firstIndex(where: { $0.id == stream.id }) else {
            fatalError("Streams \(stream) not found.")
        }
        var stream = stream

        let filename = "Stream-Thumbnail-\(stream.id).png"
        let cacheURL = FileManager.sharedCacheLocation()
        let fileURL = cacheURL.appendingPathComponent(filename)
        if (try? data.write(to: fileURL, options: .atomicWrite)) != nil {
            stream.thumbnailImageFilename = filename
            streams[index] = stream
        }

        return stream
    }
}
