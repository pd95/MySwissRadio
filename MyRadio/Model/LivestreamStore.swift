//
//  LivestreamStore.swift
//  MyRadio
//
//  Created by Philipp on 19.10.20.
//

import Foundation
import Combine
import SwiftUI

final class LivestreamStore: ObservableObject {

    init(_ streams: [Livestream]) {
        self.streams = streams

        // Create lookup dictionary
        var streamLookup: [String: Int] = Dictionary(minimumCapacity: streams.count)
        streams.enumerated().forEach { (index, stream) in
            streamLookup[stream.id] = index
        }
        self.streamIDToIndexMap = streamLookup
    }

    @Published private(set) var streams: [Livestream]

    private var streamIDToIndexMap: [String: Int]

    // MARK: - Accessors

    func streams(for bu: BusinessUnit) -> [Livestream] {
        streams.filter({ $0.bu == bu })
    }

    func stream(withID streamID: String) -> Livestream? {
        guard let index = streamIDToIndexMap[streamID] else { return nil }
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
        guard let index = streamIDToIndexMap[stream.id] else {
            fatalError("Streams \(stream) not found.")
        }
        streams[index] = stream
    }

    @discardableResult
    func saveThumbnailData(_ data: Data, for stream: Livestream) -> Livestream {
        guard let index = streamIDToIndexMap[stream.id] else {
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
