//
//  NetworkClient.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import os.log
import UIKit

struct NetworkClient {

    /// This is the main apps shared instance of the `NetworkClient`: It has OAuth configured and therefore can use `authenticatedDataRequest`
    /// For extensions which simply need to fetch resources, you can still create a `NetworkClient` without oauthConfig
    static let shared = NetworkClient(
        urlSession: .shared, oauthConfig: OAuthConfiguration(fromBundle: .main, prefix: "SRG_")
    )

    private let logger = Logger(subsystem: "MyRadio", category: "NetworkClient")

    private let authenticator: OAuthenticator?

    private let urlSession: URLSession = .shared

    enum NetworkClientError: Error {
        case urlError(URLError)
        case httpError(Int)
    }

    init(urlSession: URLSession = .shared, oauthConfig: OAuthConfiguration? = nil) {
        logger.debug("init()")

        if let config = oauthConfig {
            authenticator = OAuthenticator(configuration: config, urlSession: urlSession)
            // authenticator.invalidateToken()
            // authenticator.refreshToken(delay: 0)
        } else {
            authenticator = nil
        }

        logger.debug("init() done")
    }

    /// Internal helper function analysing the outcome of the `DataTaskPublisher`, checking the HTTP
    /// status code for a valid server response and returning an appropriate error.
    /// - Parameter result: `result` coming as an output from a `DataTaskPublisher`
    /// - Returns: publisher of the raw data
    private func handleDataTaskPublisherResponse(_ result: URLSession.DataTaskPublisher.Output) -> AnyPublisher<Data, NetworkClientError> {
        guard let httpResponse = result.response as? HTTPURLResponse else {
            fatalError("Invalid response for \(result.response.url?.absoluteString ?? ""): \(result.response) with data \(result.data)")
        }

        // Handle request and server errors
        if !(200...399 ~= httpResponse.statusCode) {
            logger.error("received \(httpResponse.statusCode): error \(String(data: result.data, encoding: .utf8) ?? "-")")
            return Fail<Data, NetworkClientError>(error: .httpError(httpResponse.statusCode))
                .eraseToAnyPublisher()
        }

        logger.debug("successful data task for \(result.response.url!), propagating data \(result.data)")
        return Just(result.data)
            .setFailureType(to: NetworkClientError.self)
            .eraseToAnyPublisher()
    }

    /// Returns a publisher that delivers the result of a regular HTTP data request for  the given URL.
    /// No authentication  is handled - intended for resources only
    ///
    /// - Parameter for: resource URL
    /// - Returns: A publisher of the data received for the given URL
    func dataRequest(for url: URL) -> AnyPublisher<Data, NetworkClientError> {
        logger.log("requestResource(for: \(url))")
        return urlSession.dataTaskPublisher(for: url)
            .mapError({ NetworkClientError.urlError($0) })
            .flatMap(handleDataTaskPublisherResponse)
            .eraseToAnyPublisher()
    }

    /// Returns a publisher that delivers the result of an authenticated HTTP request on the configured `URLSession`
    ///
    /// To authenticate, the `OAuthenticator`s access token is fetched and passed in the HTTP header field
    /// "Authorization" as a bearer token. If the access token is invalid or has expired, the token is refreshed (by the authenticator)
    /// up to 5 times with increasing timeouts.
    ///
    /// - Parameter url: target URL
    /// - Returns: A publisher of the data received for the given URL
    func authenticatedDataRequest(for request: URLRequest) -> AnyPublisher<Data, NetworkClientError> {
        logger.log("requestData(for: \(request))")

        guard let authenticator = authenticator else {
            fatalError("Authenticator not configured")
        }

        let maxFailureCount = 5
        var refreshFailureCount = 0

        // Prepare request with bearer token
        var urlRequest = request
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        urlRequest.timeoutInterval = TimeInterval(30)

        return authenticator.tokenSubject
            .flatMap({ (token: OAuthenticator.TokenState) -> AnyPublisher<Data, NetworkClientError> in

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

                urlRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

                // Execute request
                logger.debug("running data task for: \(urlRequest.url!) using \(bearerToken)")
                return urlSession.dataTaskPublisher(for: urlRequest)
                    .mapError({ NetworkClientError.urlError($0) })
                    .flatMap({ result -> AnyPublisher<Data, NetworkClientError> in
                        // Handle access denied/forbidden by triggering a access token refresh
                        guard let httpResponse = result.response as? HTTPURLResponse,
                              httpResponse.statusCode != 401 && httpResponse.statusCode != 403
                        else {
                            logger.debug("received HTTP 401/403: refreshing access token")
                            refreshFailureCount += 1
                            if refreshFailureCount <= maxFailureCount {
                                authenticator.refreshToken(
                                    delay: TimeInterval(min(1<<refreshFailureCount - 1, 5 * 60)),
                                    oldTokenValue: bearerToken
                                )
                            }
                            logger.debug("refreshing token triggered, sending Empty()")
                            return Empty()
                                .setFailureType(to: NetworkClientError.self)
                                .eraseToAnyPublisher()
                        }

                        return handleDataTaskPublisherResponse(result)
                    })
                    .eraseToAnyPublisher()
            })
            .first()
            .eraseToAnyPublisher()
    }
}
