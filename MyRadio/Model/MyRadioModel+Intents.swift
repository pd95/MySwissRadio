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

    func handlePlayIntent(_ intent: INIntent) -> [String: Any]? {
        let logger = Logger(subsystem: "MyRadioModel", category: "handleIntent")

        let streamID: String
        // Handle INPlayMediaIntent coming from Siri & Shortcuts
        if let intent = intent as? INPlayMediaIntent {
            if let item = intent.mediaItems?.first,
               let itemID = item.identifier
            {
                streamID = itemID
            }
            else {
                logger.error("Invalid media item in intent: \(intent)")
                return nil
            }
        }

        // Handle ConfigurationIntent coming from Widget
        else if let intent = intent as? ConfigurationIntent {
            if let station = intent.Station,
               let stationID = station.identifier
            {
                streamID = stationID
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

        if let stream = stream(withID: streamID) {
            play(stream)
            return stream.nowPlayingInfo
        }
        else {
            logger.error("Unable to find stream with ID \(streamID)")
            return nil
        }
    }
}
