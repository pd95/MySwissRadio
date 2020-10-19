//
//  LivestreamStore+Networking.swift
//  MyRadio
//
//  Created by Philipp on 19.10.20.
//

import Foundation
import Combine
import UIKit
import os.log

extension LivestreamStore {

    func refreshLivestreamPublisher() -> AnyPublisher<[Livestream], Never> {
        let networkClient = NetworkClient.shared

        let logger = Logger(subsystem: "LivestreamStore", category: "refreshLivestreamPublisher")

        // All updates of the streams have to be executed on our serial queue
        let serialQueue = DispatchQueue(label: "refreshSerialQueue")
        serialQueue.sync {
            self.removeAll()
        }

        /// Publisher of `Livestream`:
        /// 1. Fetch for each business unit the list of available live streams (`[Livestream]`)
        /// 2. Split arrays up into separate `Livestream`
        /// 3. For each `Livestream` we fetch URLs and update the stream
        let livestreamsPublisher: AnyPublisher<Livestream, Never> = BusinessUnit.allCases.publisher
            .flatMap({
                SRGService.getLivestreams(client: networkClient, bu: $0.apiBusinessUnit)
            })
            .receive(on: serialQueue)
            .flatMap({[weak self] streams -> AnyPublisher<Livestream, Never> in
                self?.append(streams: streams)
                return Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({[weak self] (stream: Livestream) -> AnyPublisher<Livestream, Never> in
                SRGService.getMediaResource(client: networkClient, for: stream.id, bu: stream.bu.apiBusinessUnit)
                    .receive(on: serialQueue)
                    .map { (streamUrls: [URL]) -> Livestream in
                        var streamWithURL = stream
                        streamWithURL.streams = streamUrls
                        self?.update(stream: streamWithURL)
                        return streamWithURL
                    }
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()

        /// Fetch all the images individually and regroup the streams again into `[Livestream]`
        let imageDownloadPublisher: AnyPublisher<[Livestream], Never> = livestreamsPublisher
            .flatMap({ (stream: Livestream) -> AnyPublisher<Livestream, Never> in
                SRGService.getImageResource(client: networkClient, for: stream.thumbnailImageURL)
                    .receive(on: serialQueue)
                    .map { [weak self] image -> Livestream in
                        guard let self = self else { return stream }

                        if let image = image,
                           let data = image.pngData()
                        {
                            logger.log("saving thumbnail image for \(String(describing: stream))")
                            return self.saveThumbnailData(data, for: stream)
                        }
                        else {
                            logger.log("No valid image for \(String(describing: stream))")
                            return stream
                        }
                    }
                    .eraseToAnyPublisher()
            })
            .collect()
            .handleEvents(receiveCompletion: { completion in
                logger.log("completed with \(String(describing: completion))")
            })
            .eraseToAnyPublisher()

        return imageDownloadPublisher
    }
}
