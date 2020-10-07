//
//  NetworkClient.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import os.log

struct NetworkClient {
    private let logger = Logger(subsystem: "MyRadio", category: "NetworkClient")

    static let shared = NetworkClient()

    private let baseURL: URL
    private let config: OAuthConfiguration
    private let authenticator: OAuthenticator

    private let urlSession: URLSession = .shared

    // JSON Decoder initialisation
    private let jsonDecoder : JSONDecoder

    init() {
        logger.debug("init()")
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String,
              !baseURLString.isEmpty
        else
        {
            preconditionFailure("SRG_BASE_URL not properly configured: \(Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String ?? "(none set)")")
        }
        config = OAuthConfiguration(fromBundle: .main, prefix: "SRG_", urlSession: urlSession)
        authenticator = OAuthenticator(configuration: config)
        //authenticator.invalidateToken()
        //authenticator.refreshToken(delay: 0)
        baseURL = URL(string: baseURLString.hasPrefix("https://") ? baseURLString : "https://\(baseURLString)")!

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

        jsonDecoder = decoder
        logger.debug("init() done")
    }

    private func requestData(for url: URL) -> AnyPublisher<Data, API.APIError> {
        logger.log("requestData(for: \(url))")
        let maxFailureCount = 5
        var refreshFailureCount = 0

        // Prepare request with bearer token
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: TimeInterval(30))

        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        return authenticator.tokenSubject
            .flatMap({ (token: OAuthenticator.TokenState) -> AnyPublisher<Data, API.APIError> in

                // Valid access token? Otherwise trigger a token refresh
                guard case .valid(let bearerToken, _) = token else {
                    refreshFailureCount += 1
                    logger.debug("no valid bearer token refreshing token (count \(refreshFailureCount))")
                    // Maximum retry "logic" with exponential delay increase
                    if refreshFailureCount <= maxFailureCount {
                        authenticator.refreshToken(
                            delay: refreshFailureCount > 1 ? TimeInterval(min(1<<refreshFailureCount - 1, 5 * 60)) : 0.0
                        )
                    }
                    logger.debug("refreshing token triggered, sending Empty()")
                    return Empty()
                        .eraseToAnyPublisher()
                }

                urlRequest.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

                // Execute request
                logger.debug("running data task")
                return urlSession.dataTaskPublisher(for: urlRequest)
                    .mapError({ API.APIError.urlError($0) })
                    .flatMap({ result -> AnyPublisher<Data, API.APIError> in
                        // Handle access denied/forbidden by triggering a access token refresh
                        guard let httpResponse = result.response as? HTTPURLResponse,
                              httpResponse.statusCode != 401 && httpResponse.statusCode != 403
                        else {
                            logger.debug("received HTTP 401/403: refreshing access token")
                            refreshFailureCount += 1
                            if refreshFailureCount <= maxFailureCount {
                                authenticator.refreshToken(
                                    delay: TimeInterval(min(1<<refreshFailureCount - 1, 5 * 60))
                                )
                            }
                            logger.debug("refreshing token triggered, sending Empty()")
                            return Empty()
                                .setFailureType(to: API.APIError.self)
                                .eraseToAnyPublisher()
                        }

                        // Handle request and server errors
                        if !(200...399 ~= httpResponse.statusCode) {
                            let errorResponse = try? JSONDecoder().decode(API.ErrorResponse.self, from: result.data)
                            logger.error("received \(httpResponse.statusCode): error \(errorResponse?.status.msg ?? "-")")
                            return Fail<Data, API.APIError>(error: .httpError(httpResponse.statusCode, errorResponse?.status))
                                .eraseToAnyPublisher()
                        }

                        logger.debug("successful data task, propagating data \(result.data)")
                        return Just(result.data)
                            .setFailureType(to: API.APIError.self)
                            .eraseToAnyPublisher()
                    })
                    .eraseToAnyPublisher()
            })
            .first()
            .eraseToAnyPublisher()
    }

    private func endPointURL(for endpoint: String, query: [String: String] = [:]) -> URL {
        guard let endPointURL = URL(string: endpoint, relativeTo: baseURL) else {
            preconditionFailure("Expected a valid URL for \(endpoint)")
        }
        guard var components = URLComponents(url: endPointURL, resolvingAgainstBaseURL: true) else {
            preconditionFailure("Valid URL components for \(endPointURL)")
        }
        let queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        components.queryItems = queryItems

        guard let url = components.url else {
            preconditionFailure("Components should generate valid URL \(components)")
        }

        return url
    }

    //MARK: - Main API calls to fetch specific content

    func getLivestreams(bu: API.BusinessUnits = .srf) -> AnyPublisher<[Livestream], Never> {
        return requestData(for: endPointURL(for: "audiometadata/v2/livestreams", query: ["bu" : bu.parameterValue]))
            .decode(type: API.GetLivestreamsResponse.self, decoder: jsonDecoder)
            .handleEvents(receiveCompletion: { (completion) in
                switch completion {
                    case .failure(let error):
                        print("getLivestreams(\(bu)) Error: \(error)")
                    default:  break
                }
            })
            .map({ (response: API.GetLivestreamsResponse) -> [Livestream] in
                response.mediaList.map({ (media: API.Media) -> Livestream in
                    Livestream(id: media.id, name: media.title, imageURL: media.imageUrl, bu: .init(from: media.vendor), streams: [])
                })
            })
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }

    func getMediaResource(for mediaID: String, bu: API.BusinessUnits = .srf) -> AnyPublisher<Livestream?, Never> {
        return requestData(for: endPointURL(for: "audiometadata/v2/mediaComposition/audios/\(mediaID)", query: ["bu" : bu.parameterValue]))
            .decode(type: API.GetMediaCompositionResponse.self, decoder: jsonDecoder)
            .handleEvents(receiveCompletion: { (completion) in
                switch completion {
                    case .failure(let error):
                        print("getMediaResource(\(mediaID), \(bu)) Error: \(error)")
                    default:  break
                }
            })
            .map({ (response: API.GetMediaCompositionResponse) -> Livestream? in
                return response.chapterList.first
                    .map({ (chapter: API.Chapter) -> Livestream in
                        let urls = chapter.resourceList.filter{ $0.streaming == .hls }
                            .sorted(by: { (lhs: API.Resource, rhs: API.Resource) -> Bool in
                                lhs.quality != rhs.quality &&
                                    lhs.quality != .sd
                            })
                            .map(\.url)
                        return Livestream(id: chapter.id, name: chapter.title, imageURL: chapter.imageUrl, bu: .init(from: chapter.vendor), streams: urls)
                    })
            })
            .replaceError(with: nil)
            .eraseToAnyPublisher()
    }
}
