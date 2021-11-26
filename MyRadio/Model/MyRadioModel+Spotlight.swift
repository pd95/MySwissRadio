//
//  MyRadioModel+Spotlight.swift
//  MyRadio
//
//  Created by Philipp on 13.10.20.
//

import CoreSpotlight
import os.log

extension MyRadioModel {

    private var logger: Logger {
        Logger(subsystem: "MyRadioModel", category: "updateSpotlight")
    }

    // Add list of streams to Spotlight
    func updateSpotlight(for streams: [Livestream]) {
        logger.debug("updateSpotlight with all streams available")
        streamStore.updateSpotlight()
    }

    // Update last usage date for a given stream
    func updateLastPlayed(for stream: Livestream, date: Date = Date()) {
        logger.debug("updateLastPlayed in Spotlight")
        streamStore.updateLastPlayed(for: stream, date: date)
    }

}
