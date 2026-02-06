//
//  LivestreamStore+Networking.swift
//  MyRadio
//
//  Created by Philipp on 19.10.20.
//

import Combine
import Foundation
import UIKit
import os.log

extension LivestreamStore {

    func refreshLivestreams(networkClient: NetworkClient = .shared) async -> [Livestream] {
        let logger = Logger(subsystem: "LivestreamStore", category: "refreshLivestream")

        removeAll()
        for bu in BusinessUnit.allCases {
            let streams = await SRGService.livestreams(client: networkClient, bu: bu.apiBusinessUnit)
            append(streams: streams)

            for var stream in streams {
                // Fetch the media URLs for the specified stream
                let urls = await SRGService.mediaResource(
                    client: networkClient,
                    for: stream.id,
                    bu: bu.apiBusinessUnit
                )
                stream.streams = urls
                update(stream: stream)

                // Fetch and validate the thumbnail image
                let thumnailURL = stream.thumbnailImageURL
                do {
                    let data = try await networkClient.data(for: thumnailURL)
                    if UIImage(data: data) != nil {
                        logger.log("saving thumbnail image for \(stream, privacy: .public)")
                        saveThumbnailData(data, for: stream)
                    } else {
                        logger.log("No valid image for \(stream, privacy: .public)")
                    }
                } catch {
                    logger.error("\(error.localizedDescription, privacy: .public)")
                }
            }
        }

        logger.debug("completed with \(String(describing: self.streams), privacy: .public)")
        updateSpotlight()

        return streams
    }
}
