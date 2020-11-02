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
        let searchableItems = streams.map(\.searchableItem)
        updateIndex(with: searchableItems)
    }

    // Update last usage date for a given stream
    func updateLastPlayed(for stream: Livestream) {
        logger.debug("updateLastPlayed in Spotlight")
        let searchableItem = stream.searchableItem
        searchableItem.attributeSet.lastUsedDate = Date()
        updateIndex(with: [searchableItem])
    }

    private func updateIndex(with searchableItems: [CSSearchableItem]) {
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { (error) in
            if let error = error {
                self.logger.error("Error while adding items to index: \(error.localizedDescription)")
            }
            else {
                self.logger.log("Successfully updated Spotlight")
            }
        }
    }
}
