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

    func refreshLivestreams(networkClient: NetworkClient = .shared) async -> [Livestream] {
        let logger = Logger(subsystem: "LivestreamStore", category: "refreshLivestream")

        removeAll()
        await withTaskGroup { group in
            for bu in BusinessUnit.allCases {
                // Process each business unit as a group
                group.addTask {
                    let streams = await SRGService.livestreams(client: networkClient, bu: bu.apiBusinessUnit)
                    await self.append(streams: streams)

                    // Process each stream as a group
                    await withTaskGroup { innerGroup in
                        for var stream in streams {
                            innerGroup.addTask {
                                // Fetch the media URLs for the specified stream
                                let urls = await SRGService.mediaResource(
                                    client: networkClient,
                                    for: stream.id,
                                    bu: bu.apiBusinessUnit
                                )
                                stream.streams = urls
                                await self.update(stream: stream)

                                // Fetch and validate the thumbnail image
                                let thumnailURL = stream.thumbnailImageURL
                                do {
                                    let data = try await networkClient.data(for: thumnailURL)
                                    if UIImage(data: data) != nil {
                                        logger.log("saving thumbnail image for \(stream, privacy: .public)")
                                        await self.saveThumbnailData(data, for: stream)
                                    } else {
                                        logger.log("No valid image for \(stream, privacy: .public)")
                                    }
                                } catch {
                                    logger.error("\(error.localizedDescription, privacy: .public)")
                                }

                                return stream
                            }
                        }

                        // Wait until all streams tasks for this BU are finished
                        await innerGroup.waitForAll()
                    }
                }
            }

            // Wait until BU tasks are finished
            await group.waitForAll()

            logger.debug("completed with \(String(describing: self.streams), privacy: .public)")

            updateSpotlight()
        }

        return streams
    }
}
