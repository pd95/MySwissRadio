//
//  IntentHandler.swift
//  MyRadioIntentHandler
//
//  Created by Philipp on 09.10.20.
//

import Intents

class IntentHandler: INExtension, ConfigurationIntentHandling, INPlayMediaIntentHandling {

    let streams = SettingsStore.shared.streams

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
        print("resolveMediaItems: mediaSearch = \(mediaSearch)")

        switch mediaSearch.mediaType {
            case .radioStation, .unknown:

                let matchingStreams: [Livestream]
                if let mediaName = mediaSearch.mediaName?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    matchingStreams = streams.filter { (stream) -> Bool in
                        stream.name.localizedCaseInsensitiveContains(mediaName)
                    }
                }
                else {
                    print("Cannot search for empty name: \(mediaSearch)")
                    completion(nil)
                    return
                }

                print("  found \(matchingStreams.count) matches: \(matchingStreams)")
                let mediaItems = matchingStreams.map(\.mediaItem)
                completion(mediaItems)

            default:
                completion(nil)
        }
    }

    func resolveMediaItems(for intent: INPlayMediaIntent, with completion: @escaping ([INPlayMediaMediaItemResolutionResult]) -> Void) {
        print("resolveMediaItems: mediaItems = \(intent.mediaItems ?? [])")

        resolveMediaItems(for: intent.mediaSearch) { optionalMediaItems in
            guard let mediaItems = optionalMediaItems else {
                completion([INPlayMediaMediaItemResolutionResult.unsupported()])
                return
            }
            completion(INPlayMediaMediaItemResolutionResult.successes(with: mediaItems))
        }
    }

    func handle(intent: INPlayMediaIntent, completion: @escaping (INPlayMediaIntentResponse) -> Void) {
        // FIXME: Playing the media should be handled in the background using .handleInApp instead of .continueInApp
        completion(INPlayMediaIntentResponse(code: .continueInApp, userActivity: nil))
    }

    override func handler(for intent: INIntent) -> Any {
        return self
    }
    
}
