//
//  PlayMediaIntentHandler.swift
//  MyRadioIntentHandler
//
//  Created by Philipp on 12.10.20.
//

import Intents
import os.log

class PlayMediaIntentHandler: NSObject, INPlayMediaIntentHandling {
    let streams = SettingsStore.shared.streams

    let logger = Logger(subsystem: "MyRadioIntentHandler", category: "PlayMediaIntentHandler")

    func resolveMediaItems(for optionalMediaSearch: INMediaSearch?, completion: @escaping ([INMediaItem]?) -> Void) {

        guard let mediaSearch = optionalMediaSearch else {
            completion(nil)
            return
        }
        logger.log("resolveMediaItems: mediaSearch.mediaName = \(mediaSearch.mediaName ?? "-")")

        switch mediaSearch.mediaType {
            case .radioStation, .unknown:

                guard let mediaName = mediaSearch.mediaName?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    logger.error("Cannot search for empty name: \(mediaSearch)")
                    completion(nil)
                    return
                }

                let matchingStreams: [Livestream] = streams.filter({ $0.matching(mediaName) })

                logger.log("  found \(matchingStreams.count) matches: \(matchingStreams)")
                let mediaItems = matchingStreams.map(\.mediaItem)
                completion(mediaItems)

            default:
                completion(nil)
        }
    }

    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        logger.log("resolveMediaItems: mediaItems = \(intent.mediaItems ?? [])")

        if let mediaItems = intent.mediaItems {
            completion(INPlayMediaMediaItemResolutionResult.successes(with: mediaItems))
        }
        else {
            resolveMediaItems(for: intent.mediaSearch) { optionalMediaItems in
                guard let mediaItems = optionalMediaItems, !mediaItems.isEmpty else {
                    self.logger.log("No matches found. Proposing all available streams to choose from.")
                    completion([INPlayMediaMediaItemResolutionResult.disambiguation(with: self.streams.map(\.mediaItem))])
                    return
                }

                if mediaItems.count == 1 {
                    // One single match
                    completion(INPlayMediaMediaItemResolutionResult.successes(with: mediaItems))
                }
                else {
                    // Multiple matches
                    completion([INPlayMediaMediaItemResolutionResult.disambiguation(with: mediaItems)])
                }
            }
        }
    }

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        logger.log("handle(mediaItem: \(String(describing: intent.mediaItems?.first!))")
        completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
    }
}
