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
    let sortOrder: Int
    var streams: [URL]
    var thumbnailImageFilename: String? = nil

    var isReady: Bool {
        !streams.isEmpty
    }

    static let example = Livestream(
        id: "dd0fa1ba-4ff6-4e1a-ab74-d7e49057d96f", name: "Radio SRF 3",
        imageURL: URL(string: "https://ws.srf.ch/asset/image/audio/e6086821-526d-45d9-a300-798cc9ea0555/EPISODE_IMAGE")!,
        bu: .srf, sortOrder: 3,
        streams: [URL(string: "https://lsaplus.swisstxt.ch/audio/drs3_96.stream/playlist.m3u8?DVR")!,
                  URL(string: "https://lsaplus.swisstxt.ch/audio/drs3_96.stream/playlist.m3u8")!]
    )
}

extension Livestream: Comparable {
    static func < (lhs: Livestream, rhs: Livestream) -> Bool {
        lhs.bu < rhs.bu && lhs.sortOrder < rhs.sortOrder
    }
}

extension Livestream {

    func imageURL(for width: Int? = nil) -> URL {
        if let width = width {
            return imageURL.appendingPathComponent("/scale/width/\(width)")
        }
        return imageURL
    }
}
