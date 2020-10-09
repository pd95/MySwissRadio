//
//  FileManager+Sharing.swift
//  MyRadio
//
//  Created by Philipp on 09.10.20.
//

import Foundation

extension FileManager {

    static func sharedContainerURL() -> URL {
        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Bundle.appGroupIdentifier
        )!
    }

    static func sharedCacheLocation() -> URL {
        let cache = sharedContainerURL().appendingPathComponent("Library/Caches/")
        return cache
    }
}
