//
//  Livestream+ImageCache.swift
//  MyRadio
//
//  Created by Philipp on 09.10.20.
//

import Foundation
import UIKit

extension Livestream {

    var thumbnailImageURL: URL {
        imageURL(for: 400)
    }

    var thumbnailImage: UIImage? {
        let thumbnailURL = thumbnailImageURL

        // Check first in in-memory cache
        if let image = ImageCache.shared[thumbnailURL] {
            return image
        }

        // Then, check on file system in the shared cache
        if let filename = thumbnailImageFilename {
            let cacheURL = FileManager.sharedCacheLocation()
            let fileURL = cacheURL.appendingPathComponent(filename)
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                ImageCache.shared[thumbnailURL] = image
                return image
            }
        }
        return nil
    }
}
