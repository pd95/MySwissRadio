//
//  LivestreamStore+Spotlight.swift
//  MyRadio
//
//  Created by Philipp on 26.11.21.
//

import Foundation
import CoreSpotlight
import os.log

extension LivestreamStore {

    private var logger: Logger {
        Logger(subsystem: "LivestreamStore", category: "Spotlight")
    }

    private func updateIndex(with items: [CSSearchableItem]) {
        CSSearchableIndex.default().indexSearchableItems(items) { (error) in
            if let error = error {
                self.logger.error("Error while adding items to index: \(error.localizedDescription, privacy: .public)")
            } else {
                self.logger.log("Successfully updated Spotlight")
            }
        }
    }

    func updateSpotlight() {
        logger.debug("updateSpotlight index with all available streams")
        let searchableItems = streams.map(\.searchableItem)
        updateIndex(with: searchableItems)
    }

    func updateLastPlayed(for stream: Livestream, date: Date = Date()) {
        logger.debug("updateLastPlayed in Spotlight")
        let searchableItem = stream.searchableItem
        searchableItem.attributeSet.lastUsedDate = date
        updateIndex(with: [searchableItem])
    }
}
