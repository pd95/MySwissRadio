//
//  Livestream+INMediaItem.swift
//  MyRadio
//
//  Created by Philipp on 11.10.20.
//

import Foundation
import Intents
import MediaPlayer

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

    var nowPlayingInfo: [String: Any] {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: name,
            MPMediaItemPropertyMediaType: MPMediaType.anyAudio.rawValue,
            MPNowPlayingInfoCollectionIdentifier: bu.description,
        ]

        if let image = thumbnailImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { (_) -> UIImage in
                return image
            }

            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        return nowPlayingInfo
    }
}
