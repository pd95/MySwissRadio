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

    // MARK: - Main API calls to fetch specific content

    static func getLivestreams(client: NetworkClient, bu: SRGService.BusinessUnit = .srf) -> AnyPublisher<[Livestream], Never> {
        return client.authenticatedDataRequest(for: .livestreams(bu: bu))
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
                    Livestream(id: media.id, name: media.title, imageURL: media.imageUrl,
                               bu: .init(from: media.vendor), sortOrder: index, streams: [])
                })
            })
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    static func getMediaResource(client: NetworkClient, for mediaID: String, bu: SRGService.BusinessUnit = .srf) -> AnyPublisher<[URL], Never> {
        return client.authenticatedDataRequest(for: .mediaComposition(for: mediaID, bu: bu))
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
                        let urls = chapter.resourceList.filter({ $0.streaming == .hls })
                            .sorted(by: { (lhs: SRGService.Resource, rhs: SRGService.Resource) -> Bool in
                                lhs.quality != rhs.quality &&
                                    lhs.quality != .sd
                            })
                            .map(\.url)
                        return urls
                    })
                return mediaURLs
            })
            .replaceError(with: [])
            .replaceNil(with: [])
            .eraseToAnyPublisher()
    }

    static func getImageResource(client: NetworkClient, for url: URL) -> AnyPublisher<UIImage?, Never> {
        return client.dataRequest(for: url)
            .map({ UIImage(data: $0) })
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
}

// MARK: - Data structures used in the API
extension SRGService {

    enum BusinessUnit: String, Decodable, CaseIterable {
        case srf = "SRF", rsi = "RSI", rtr = "RTR", rts = "RTS", swi = "SWI"

        var parameterValue: String { self.rawValue.lowercased() }
    }

    enum TransmissionType: String, Decodable {
        case radio = "RADIO", tv = "TV"
    }

    // MARK: - SRGSSR Audio Metadata

    enum MediaType: String, Decodable {
        case audio = "AUDIO", video = "VIDEO"
    }

    enum StreamType: String, Decodable {
        case livestream = "LIVESTREAM"
    }

    enum Quality: String, Decodable {
        case sd = "SD", hd = "HD", hq = "HQ"
    }

    enum Encoding: String, Decodable {
        case aac = "AAC", mp3 = "MP3", h264 = "H264"
    }

    enum Presentation: String, Decodable {
        case `default` = "DEFAULT"
    }

    enum Streaming: String, Decodable {
        case hls = "HLS"
        case hds = "HDS"
        case rtmp = "RTMP"
        case m3uPlaylist = "M3UPLAYLIST"
        case progressive = "PROGRESSIVE"
    }

    enum MediaContainer: String, Decodable {
        case none = "NONE"
        case mpeg2ts = "MPEG2_TS"
    }

    enum AudioCodec: String, Decodable {
        case none = "NONE", aac = "AAC", mp3 = "MP3"
        case unknown = "UNKNOWN"
    }

    enum VideoCodec: String, Decodable {
        case none = "NONE"
    }

    enum TokenType: String, Decodable {
        case none = "NONE"
    }

    struct Channel: Decodable {
        let id: String
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let imageUrl: URL
        let imageTitle: String?
        let imageCopyright: String?
        let transmission: TransmissionType
    }

    struct Media: Decodable {
        let id: String
        let mediaType: MediaType
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let description: String?
        let imageUrl: URL
        let imageTitle: String?
        let type: StreamType
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
        let transmission: TransmissionType
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
        let quality: Quality
        let `protocol`: String
        let encoding: Encoding
        let mimeType: String
        let presentation: Presentation
        let streaming: Streaming
        let dvr: Bool
        let live: Bool
        let mediaContainer: MediaContainer
        let audioCodec: AudioCodec
        let videoCodec: VideoCodec
        let tokenType: TokenType
        // let analyticsMetadata: AnalyticsMetaDataResource
        let streamOffset: Int?
    }

    struct Chapter: Decodable {
        let id: String
        let mediaType: MediaType
        let vendor: BusinessUnit
        let urn: String
        let title: String
        let description: String?
        let imageUrl: URL
        let imageTitle: String?
        let type: StreamType
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
