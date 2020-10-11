//
//  Livestream+INMediaItem.swift
//  MyRadio
//
//  Created by Philipp on 11.10.20.
//

import Foundation
import Intents

extension Livestream {
    var mediaItem: INMediaItem {
        var image: INImage? = nil
        if let thumbnail = thumbnailImage,
           let imageData = thumbnail.pngData() {
            image = INImage(imageData: imageData)
        }
        let media = INMediaItem(identifier: id, title: name, type: .radioStation, artwork: image)
        return media
    }
}
