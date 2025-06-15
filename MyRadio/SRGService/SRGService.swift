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

}

extension SRGService {
    static func livestreams(client: NetworkClient, bu: SRGService.BusinessUnit = .srf) async -> [Livestream] {
        await  client.authenticatedDataRequest(for: .livestreams(bu: bu))
            .decode(type: SRGService.GetLivestreamsResponse.self, decoder: SRGService.jsonDecoder)
            .handleEvents(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    SRGService.logger.error("🔴 getLivestreams(\(bu.rawValue)) Error: \(error.localizedDescription, privacy: .public)")
                default:  break
                }
            })
            .map({ (response: SRGService.GetLivestreamsResponse) -> [Livestream] in
                let enumeratedMedia = response.mediaList.enumerated()

                return enumeratedMedia.map({ (index, media) -> Livestream in
                    Livestream(id: media.id, name: media.title, imageURL: media.channel.imageUrl,
                               bu: .init(from: media.vendor), sortOrder: index, streams: [])
                })
            })
            .replaceError(with: [])
            .values
            .first(where: { _ in true }) ?? []
    }

    static func mediaResource(
        client: NetworkClient,
        for mediaID: String,
        bu: SRGService.BusinessUnit = .srf
    ) async -> [URL] {
        await client.authenticatedDataRequest(for: .mediaComposition(for: mediaID, bu: bu))
            .decode(type: SRGService.GetMediaCompositionResponse.self, decoder: SRGService.jsonDecoder)
            .handleEvents(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    SRGService.logger.error("🔴 getMediaResource(\(mediaID, privacy: .public), \(bu.rawValue)) Error: \(error.localizedDescription, privacy: .public)")
                default:
                    break
                }
            })
            .map({ (response: SRGService.GetMediaCompositionResponse) -> [URL]? in
                let mediaURLs = response.chapterList.first
                    .map({ (chapter: SRGService.Chapter) -> [URL] in
                        let urls = chapter.resourceList.filter({ $0.streaming == "HLS" })
                            .sorted(by: { (lhs: SRGService.Resource, rhs: SRGService.Resource) -> Bool in
                                lhs.quality != rhs.quality &&
                                    lhs.quality != "SD"
                            })
                            .map(\.url)
                        return urls
                    })
                return mediaURLs
            })
            .replaceError(with: [])
            .replaceNil(with: [])
            .values
            .first(where: { _ in true }) ?? []
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
