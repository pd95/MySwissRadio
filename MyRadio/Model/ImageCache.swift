//
//  ImageCache.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import Foundation
import UIKit

class ImageCache {

    static let shared = ImageCache()

    private var cache = NSCache<NSString, UIImage>()

    private init() {}

    subscript(_ key: String) -> UIImage? {
        get {
            cache.object(forKey: NSString(string: key))
        }
        set {
            if let image = newValue {
                cache.setObject(image, forKey: NSString(string: key))
            }
        }
    }

    subscript(_ url: URL) -> UIImage? {
        get {
            cache.object(forKey: NSString(string: url.absoluteString))
        }
        set {
            if let image = newValue {
                cache.setObject(image, forKey: NSString(string: url.absoluteString))
            }
        }
    }
}
