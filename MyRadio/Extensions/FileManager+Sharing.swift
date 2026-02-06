//
//  FileManager+Sharing.swift
//  MyRadio
//
//  Created by Philipp on 09.10.20.
//

import Foundation

extension FileManager {

    static func sharedContainerURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Bundle.appGroupIdentifier
        )
    }

    static func sharedCacheLocation() -> URL {
        let url: URL
        if let sharedContainer = sharedContainerURL() {
            url = sharedContainer.appendingPathComponent("Library/Caches")
        } else {
            if #available(iOS 16.0, *) {
                url = URL.cachesDirectory
            } else {
                url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            }
        }
        return url
    }
}
