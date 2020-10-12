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
            MPMediaItemPropertyArtist: "My radio"
        ]

        if let image = thumbnailImage {
            let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 60, height: 60)) { (_) -> UIImage in
                return image
            }

            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        return nowPlayingInfo
    }
}
