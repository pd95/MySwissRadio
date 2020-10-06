//
//  API.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

enum API {

    enum BusinessUnits: String, Decodable, CaseIterable {
        case srf = "SRF", rsi = "RSI", rtr = "RTR", rts = "RTS", swi = "SWI"

        var parameterValue: String { self.rawValue.lowercased() }
    }

    enum TransmissionType: String, Decodable {
        case radio = "RADIO", tv = "TV"
    }

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
        let vendor: BusinessUnits
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
        let vendor: BusinessUnits
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
        let vendor: BusinessUnits
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
        let vendor: BusinessUnits
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


    struct Status: Decodable {
        let code: Int
        let msg: String
    }

    struct ErrorResponse: Decodable {
        let status: Status
    }

    enum APIError: Error {
        case unknown
        case httpError(Int, Status?)
        case urlError(URLError)
    }
}
