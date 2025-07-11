//
//  SRGService.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import UIKit
import os.log

enum SRGService {

    static let logger = Logger(subsystem: "MyRadio", category: "SRGService")

    static let jsonDecoder: JSONDecoder = initJSONDecoder()

    // JSON Decoder initialisation
    private static func initJSONDecoder() -> JSONDecoder {
        // We cannot use the dateDecodingStrategy iso8601 as we have sometimes fractional seconds
        // So we use our own JSONDecoder date formatter configuration
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let date = dateFormatter.date(from: dateStr) {
                return date
            }
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            return dateFormatter.date(from: dateStr)!
        })
        return decoder
    }

    static func livestreams(client: NetworkClient, bu: SRGService.BusinessUnit = .srf) async -> [Livestream] {
        var liveStreams: [Livestream]?
        do {
            let data = try await client.authenticatedData(for: .livestreams(bu: bu))
            let response = try jsonDecoder.decode(GetLivestreamsResponse.self, from: data)
            liveStreams = response.mediaList.enumerated()
                .map({ (index, media) -> Livestream in
                    Livestream(id: media.id, name: media.title, imageURL: media.channel.imageUrl,
                               bu: .init(from: media.vendor), sortOrder: index, streams: [])
                })
        } catch {
            logger.error("🔴 livestreams(\(bu.rawValue)) failed with error: \(error.localizedDescription, privacy: .public)")
        }

        return liveStreams ?? []
    }

    static func mediaResource(
        client: NetworkClient,
        for mediaID: String,
        bu: SRGService.BusinessUnit = .srf
    ) async -> [URL] {
        var mediaURLs: [URL]?
        do {
            let data = try await client.authenticatedData(for: .mediaComposition(for: mediaID, bu: bu))
            let response = try jsonDecoder.decode(GetMediaCompositionResponse.self, from: data)
            mediaURLs = response.chapterList.first
                .map({ (chapter: SRGService.Chapter) -> [URL] in
                    let urls = chapter.resourceList.filter({ $0.streaming == "HLS" })
                        .sorted(by: { (lhs: SRGService.Resource, rhs: SRGService.Resource) -> Bool in
                            lhs.quality != rhs.quality &&
                                lhs.quality != "SD"
                        })
                        .map(\.url)
                    return urls
                })
        } catch {
            logger.error("🔴 mediaResource(\(mediaID, privacy: .public), \(bu.rawValue)) failed with error: \(error.localizedDescription, privacy: .public)")
        }

        return mediaURLs ?? []
    }
}

// MARK: - Data structures used in the API
extension SRGService {

    enum BusinessUnit: String, Decodable, CaseIterable {
        case srf = "SRF", rsi = "RSI", rtr = "RTR", rts = "RTS", swi = "SWI"

        var parameterValue: String { self.rawValue.lowercased() }
    }

    // MARK: - SRGSSR Audio Metadata

    struct Channel: Decodable {
        let id: String
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let imageUrl: URL
        let imageTitle: String?
        let imageCopyright: String?
        let transmission: String
    }

    struct Media: Decodable {
        let id: String
        let mediaType: String
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let description: String?
        let imageUrl: URL
        let imageTitle: String?
        let type: String
        let date: Date
        let duration: Int
        let playableAbroad: Bool
        let channel: Channel
        let presentation: String?
    }

    struct Episode: Decodable {
        let id: String
        let title: String
        let lead: String?
        let description: String?
        let publishedDate: Date?
        let imageUrl: URL
        let imageTitle: String?
    }

    struct Show: Decodable {
        let id: String
        let vendor: BusinessUnit
        let transmission: String
        let urn: String
        let title: String
        let lead: String?
        let description: String?
        let imageUrl: URL
        let imageTitle: String?
        let bannerImageUrl: URL?
        let posterImageUrl: URL
        let posterImageIsFallbackUrl: Bool
        let primaryChannelId: String
        let primaryChannelUrn: String
    }

    struct Resource: Decodable {
        let url: URL
        let quality: String
        let `protocol`: String
        let encoding: String
        let mimeType: String
        let presentation: String
        let streaming: String
        let dvr: Bool
        let live: Bool
        let mediaContainer: String
        let audioCodec: String
        let videoCodec: String
        let tokenType: String
        // let analyticsMetadata: AnalyticsMetaDataResource
        let streamOffset: Int?
    }

    struct Chapter: Decodable {
        let id: String
        let mediaType: String
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let description: String?
        let imageUrl: URL
        let imageTitle: String?
        let type: String
        let date: Date
        let duration: Int
        let playableAbroad: Bool
        let displayable: Bool
        let position: Int
        let noEmbed: Bool
        // let analyticsMetadata: AnalyticsMetaDataChapter
        // let eventData: String
        let fullLengthMarkIn: Int?
        let fullLengthMarkOut: Int?
        let resourceList: [Resource]
    }

    struct GetLivestreamsResponse: Decodable {
        let mediaList: [Media]
    }

    struct GetMediaCompositionResponse: Decodable {
        let chapterUrn: String
        let episode: Episode
        let show: Show?
        let channel: Channel
        let chapterList: [Chapter]
        // let analyticsData: AnalyticsMetaData
        // let analyticsMetadata: AnalyticsMetaDataChapter
    }

    struct ErrorStatusCode: Decodable {
        let code: Int
        let msg: String
    }

    struct ErrorResponse: Decodable {
        let status: ErrorStatusCode
    }
}
