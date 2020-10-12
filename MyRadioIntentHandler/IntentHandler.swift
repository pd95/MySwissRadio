//
//  IntentHandler.swift
//  MyRadioIntentHandler
//
//  Created by Philipp on 09.10.20.
//

import Intents
import os.log

class IntentHandler: INExtension, ConfigurationIntentHandling, INPlayMediaIntentHandling {

    let streams = SettingsStore.shared.streams
    let logger = Logger(subsystem: "MyRadioIntentHandler", category: "IntentHandler")

    // MARK: - ConfigurationIntentHandling (used for Widget configuration)
    var allStations: [Station] {
        return streams.sorted().map { stream in
            Station(identifier: stream.id, display: stream.name)
        }
    }

    func provideStationOptionsCollection(for intent: ConfigurationIntent,
                                     with completion: @escaping (INObjectCollection<Station>?, Error?) -> Void)
    {
        let stations = allStations

        let collection = INObjectCollection(items: stations)
        completion(collection, nil)
    }

    func defaultStation(for intent: ConfigurationIntent) -> Station? {
        return nil
    }

    func resolveStation(for intent: ConfigurationIntent,
                        with completion: @escaping (StationResolutionResult) -> Void)
    {
        let result: StationResolutionResult
        if let station = intent.Station {
            result = .success(with: station)
        }
        else {
            print("resolveStation without station called")
            result = .disambiguation(with: allStations)
        }

        completion(result)
    }



    // MARK: - INPlayMediaIntentHandling

    func resolveMediaItems(for optionalMediaSearch: INMediaSearch?, completion: @escaping ([INMediaItem]?) -> Void) {

        guard let mediaSearch = optionalMediaSearch else {
            completion(nil)
            return
        }
        logger.log("resolveMediaItems: mediaSearch = \(mediaSearch)")

        switch mediaSearch.mediaType {
            case .radioStation, .unknown:

                let matchingStreams: [Livestream]
                if let mediaName = mediaSearch.mediaName?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    matchingStreams = streams.filter { (stream) -> Bool in
                        stream.name.localizedCaseInsensitiveContains(mediaName)
                    }
                }
                else {
                    logger.error("Cannot search for empty name: \(mediaSearch)")
                    completion(nil)
                    return
                }

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
                guard let mediaItems = optionalMediaItems else {
                    completion([INPlayMediaMediaItemResolutionResult.unsupported()])
                    return
                }
                completion(INPlayMediaMediaItemResolutionResult.successes(with: mediaItems))
            }
        }
    }

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        logger.log("handle(mediaItem: \(String(describing: intent.mediaItems?.first!))")
        completion(INPlayMediaIntentResponse(code: .handleInApp, userActivity: nil))
    }

    override func handler(for intent: INIntent) -> Any {
        return self
    }
    
}
