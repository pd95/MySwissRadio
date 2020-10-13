//
//  MyRadioModel+Spotlight.swift
//  MyRadio
//
//  Created by Philipp on 13.10.20.
//

import CoreSpotlight
import os.log

extension MyRadioModel {

    // Add list of streams to Spotlight
    func updateSpotlight(for streams: [Livestream]) {
        let searchableItems = streams.map(\.searchableItem)
        updateIndex(with: searchableItems)
    }

    // Update last usage date for a given stream
    func updateLastPlayed(for stream: Livestream) {
        let searchableItem = stream.searchableItem
        searchableItem.attributeSet.lastUsedDate = Date()
        updateIndex(with: [searchableItem])
    }

    private func updateIndex(with searchableItems: [CSSearchableItem]) {
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { (error) in
            let logger = Logger(subsystem: "MyRadioModel", category: "updateSpotlight")
            if let error = error {
                logger.error("Error while adding items to index: \(error.localizedDescription)")
            }
            else {
                logger.log("Successfully updated Spotlight")
            }
        }
    }
}
