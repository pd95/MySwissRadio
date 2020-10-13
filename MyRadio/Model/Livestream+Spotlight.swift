//
//  Livestream+CoreSpotlight.swift
//  MyRadio
//
//  Created by Philipp on 13.10.20.
//

import CoreSpotlight

extension Livestream {
    var searchableItem: CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .audio)
        attributes.title = name
        attributes.thumbnailData = thumbnailImage?.pngData()

        return CSSearchableItem(uniqueIdentifier: id, domainIdentifier: bu.description, attributeSet: attributes)
    }
}
