//
//  MyRadioModel+Intents.swift
//  MyRadio
//
//  Created by Philipp on 12.10.20.
//

import Foundation
import os.log
import Intents

extension MyRadioModel: INPlayMediaIntentHandling {

    /// Helper function extracting the list of words which are used in the stream name and business unit description
    /// to be matched against the Siri provided search query
    func updateSiriSearch(_ streams: [Livestream]) {
        var wordToStreamsMap = [String:[Livestream.ID]]()

        let nf = NumberFormatter()
        nf.numberStyle = .spellOut
        nf.locale = Locale(identifier: INPreferences.siriLanguageCode())

        for stream in streams {
            // Gather all words related to this stream
            var searchWords: [String] = []

            // Split name into separate words and number strings
            searchWords = stream.name.matches(regex: "[[:alpha:]]+|\\d+")

            // Get spelled out words for the numbers
            let numberWords = searchWords.compactMap({Int($0)}).compactMap({ nf.string(for: $0) })
            searchWords.append(contentsOf: numberWords)

            // Add the business units name for search too
            searchWords.append(stream.bu.description)

            // Add all those words to the mapping
            searchWords.forEach { (word) in
                let lowercasedWord = word.lowercased()
                let streamArray = wordToStreamsMap[lowercasedWord, default: []]
                if !streamArray.contains(stream.id) {
                    wordToStreamsMap[lowercasedWord, default: []].append(stream.id)
                }
            }
        }

        SettingsStore.shared.wordToStreamsMap = wordToStreamsMap
    }

    // MARK: INPlayMediaIntentHandling implementation
    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {

        let result: INPlayMediaIntentResponse
        if let nowPlaying = handlePlayIntent(intent) {
            result = INPlayMediaIntentResponse(code: .success, userActivity: nil)
            result.nowPlayingInfo = nowPlaying
        }
        else {
            result = INPlayMediaIntentResponse(code: .failure, userActivity: nil)
        }
        completion(result)
    }

    // MARK: Helper to extract Livestream.ID from specific intent
    func handlePlayIntent(_ intent: INIntent) -> [String: Any]? {
        let logger = Logger(subsystem: "MyRadioModel", category: "handleIntent")

        // Handle INPlayMediaIntent coming from Siri & Shortcuts
        if let intent = intent as? INPlayMediaIntent {
            if let item = intent.mediaItems?.first,
               let itemID = item.identifier
            {
                if let stream = streamStore.stream(withID: itemID) {
                    play(stream)
                    return stream.nowPlayingInfo
                }
                logger.error("Invalid itemID in intent: \(itemID)")
                return nil
            }
            else {
                logger.error("Invalid media item in intent: \(intent)")
                return nil
            }
        }

        // Handle ConfigurationIntent coming from Widget
        else if let intent = intent as? ConfigurationIntent {
            if let station = intent.station,
               let stationID = station.identifier ?? SettingsStore.shared.lastPlayedStreamId
            {
                if let stream = streamStore.stream(withID: stationID) {
                    play(stream)
                    showSheet = true
                    return stream.nowPlayingInfo
                }
                logger.error("Invalid stationID in intent: \(stationID)")
                return nil
            }
            else {
                logger.error("Invalid station in intent: \(intent)")
                return nil
            }
        }
        else {
            logger.error("Invalid intent: \(intent)")
            return nil
        }
    }
}
