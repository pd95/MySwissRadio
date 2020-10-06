//
//  NetworkClient.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine

struct NetworkClient {

    static let shared = NetworkClient()

    private let baseURL: URL
    private let config: OAuthConfiguration
    private let authenticator: OAuthenticator

    private let urlSession: URLSession = .shared

    init() {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String,
              !baseURLString.isEmpty else
        {
            preconditionFailure("SRG_BASE_URL not properly condifgured: \(Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String ?? "(none set)")")
        }
        config = OAuthConfiguration(fromBundle: .main, prefix: "SRG_", urlSession: urlSession)
        authenticator = OAuthenticator(configuration: config)
        authenticator.refreshToken(delay: 0)
        baseURL = URL(string: baseURLString.hasPrefix("https://") ? baseURLString : "https://\(baseURLString)")!
    }

    private func requestData(for url: URL) -> AnyPublisher<Data, URLError> {
        let tokenSubject = authenticator.tokenSubject
        let maxFailureCount = 5
        var refreshFailureCount = 0

        // Prepare request with bearer token
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: TimeInterval(30))

        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")

        return tokenSubject
            .flatMap({ (token: OAuthenticator.TokenState) -> AnyPublisher<Data, URLError> in

                // Valid access token? Otherwise trigger a token refresh
                guard case .valid(let bearerToken, _) = token else {
                    refreshFailureCount += 1
                    // Maximum retry "logic" with exponential delay increase
                    if refreshFailureCount <= maxFailureCount {
                        authenticator.refreshToken(
                            delay: refreshFailureCount > 1 ? TimeInterval(min(1<<refreshFailureCount - 1, 5 * 60)) : 0.0
                        )
                    }
                    return Empty()
                        .eraseToAnyPublisher()
                }

                urlRequest.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

                // Execute request
                return urlSession.dataTaskPublisher(for: urlRequest)
                    .flatMap({ result -> AnyPublisher<Data, URLError> in
                        // Handle access denied/forbidden by triggering a access token refresh
                        guard let httpResponse = result.response as? HTTPURLResponse,
                              httpResponse.statusCode != 401 && httpResponse.statusCode != 403
                        else {
                            refreshFailureCount += 1
                            if refreshFailureCount <= maxFailureCount {
                                authenticator.refreshToken(
                                    delay: TimeInterval(min(1<<refreshFailureCount - 1, 5 * 60))
                                )
                            }
                            return Empty()
                                .eraseToAnyPublisher()
                        }

                        return Just(result.data)
                            .setFailureType(to: URLError.self)
                            .eraseToAnyPublisher()
                    })
                    .eraseToAnyPublisher()
            })
            .handleEvents(receiveOutput: { data in
                tokenSubject.send(completion: .finished)
            })
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

    func getChannels() -> AnyPublisher<[Channel], Never> {
        return requestData(for: endPointURL(for: "audiometadata/v2/radio/channels", query: ["bu" : "srf"]))
            .decode(type: GetChannelResponse.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { data in
                print("getChannels: \(data)")
            })
            .map({ (response: GetChannelResponse) -> [Channel] in
                response.channelList.map({ Channel(id: $0.id, name: $0.title, imageURL: $0.imageUrl)})
            })
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}


struct GetChannelResponse: Decodable {
    enum TransmissionType: String, Decodable {
        case radio = "RADIO", tv = "TV"
    }

    struct Channel: Decodable {
        let id: UUID
        let vendor: String
        let urn: String
        let title: String
        let imageUrl: URL
        let imageTitle: String
        let imageCopyright: String?
        let transmission: TransmissionType
    }

    let channelList: [Channel]
}
