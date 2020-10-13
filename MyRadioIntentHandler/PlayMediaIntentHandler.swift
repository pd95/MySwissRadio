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
                logger.log("Searching for \(mediaName) in \(self.streams.count) streams")

                // First try to find a direct match in the stream name
                var matchingStreams: [Livestream] = streams.filter({ mediaName.localizedCaseInsensitiveContains($0.name) })
                logger.log("  found \(matchingStreams.count) best matches: \(matchingStreams)")

                // Then, if no best match was found, try our wordToStreamsMap
                if matchingStreams.isEmpty {
                    let wordToStreamsMap = SettingsStore.shared.wordToStreamsMap

                    // Split media name into words and collect all stream IDs which have one of them
                    let mediaNameWords = mediaName.lowercased().matches(regex: "[[:alpha:]]+|\\d+")
                    var matchingStreamMap = [Livestream.ID: Int]()
                    mediaNameWords.forEach { (word) in
                        if let streamIDs = wordToStreamsMap[word] {
                            streamIDs.forEach { (streamID) in
                                matchingStreamMap[streamID, default: 0] += 1
                            }
                        }
                    }

                    // Find good matches which contain all the words we were looking for
                    let wordCount = mediaNameWords.count
                    var bestMatches = matchingStreamMap.map{$0}.filter({ $0.value == wordCount })
                    logger.log("  found \(bestMatches.count) good matches: \(bestMatches)")

                    // If there was no good match, get a sorted list of matching streams
                    if bestMatches.isEmpty {
                        let sortedStreamIds = matchingStreamMap.map {$0}
                            .sorted { $0.value > $1.value }
                        bestMatches = sortedStreamIds
                        logger.log("  found \(bestMatches.count) ok matches: \(bestMatches)")
                    }

                    matchingStreams = bestMatches.compactMap { (element) -> Livestream? in
                        streams.first { $0.id == element.key }
                    }
                    logger.log("  found \(matchingStreams.count) matches based on word list: \(matchingStreams)")
                }

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
