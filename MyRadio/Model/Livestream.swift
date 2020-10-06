//
//  Livestream.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

struct Livestream: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let imageURL: URL
    let bu: BusinessUnit
    let streams: [URL]

    var isReady: Bool {
        !streams.isEmpty
    }
}

extension Livestream: Comparable {
    static func < (lhs: Livestream, rhs: Livestream) -> Bool {
        lhs.bu < rhs.bu && lhs.name < rhs.name
    }
}
