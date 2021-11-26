//
//  IntentHandler.swift
//  MyRadioIntentHandler
//
//  Created by Philipp on 09.10.20.
//

import Intents
import os.log

class IntentHandler: INExtension, ConfigurationIntentHandling {

    let logger = Logger(subsystem: "MyRadioIntentHandler", category: "IntentHandler")

    let lastPlayedStation = Station(identifier: nil, display: "Last played")

    // MARK: - ConfigurationIntentHandling (used for Widget configuration)
    var allStations: [Station] {
        return SettingsStore.shared.streams.sorted().map { stream in
            Station(identifier: stream.id, display: stream.name)
        }
    }

    func provideStationOptionsCollection(for intent: ConfigurationIntent,
                                         with completion: @escaping (INObjectCollection<Station>?, Error?) -> Void) {
        var stations = allStations
        stations.insert(lastPlayedStation, at: 0)

        let collection = INObjectCollection(items: stations)
        completion(collection, nil)
    }

    func defaultStation(for intent: ConfigurationIntent) -> Station? {
        return lastPlayedStation
    }

    func resolveStation(for intent: ConfigurationIntent,
                        with completion: @escaping (StationResolutionResult) -> Void) {
        let result: StationResolutionResult
        if let station = intent.station {
            result = .success(with: station)
        } else {
            print("resolveStation without station called")
            result = .disambiguation(with: allStations)
        }

        completion(result)
    }

    override func handler(for intent: INIntent) -> Any {
        logger.log("handler(for: \(intent))")
        if intent is INPlayMediaIntent {
            return PlayMediaIntentHandler()
        }
        return self
    }
}
