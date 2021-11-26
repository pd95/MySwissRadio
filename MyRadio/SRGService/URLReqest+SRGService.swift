//
//  URLReqest+SRGService.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import Foundation

extension URLRequest {

    private static var baseURL: URL = initBaseURL()

    private static func initBaseURL() -> URL {
        guard let baseURLString = Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String,
              !baseURLString.isEmpty
        else {
            preconditionFailure("SRG_BASE_URL not properly configured: \(Bundle.main.object(forInfoDictionaryKey: "SRG_BASE_URL") as? String ?? "(none set)")")
        }
        return URL(string: baseURLString.hasPrefix("https://") ? baseURLString : "https://\(baseURLString)")!
    }

    /// Creates an URLRequest initialized for the given endpoint path.
    ///
    /// The expected response type is JSON and the character set UTF8
    ///
    /// - Parameters:
    ///   - endpoint: `baseURL` relativ path of the endpoint
    ///   - query: query parameters (which are going to be put into `queryItems`
    init(endpoint: String, query: [String: String] = [:]) {
        guard let endPointURL = URL(string: endpoint, relativeTo: Self.baseURL) else {
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

        self.init(url: url)

        self.addValue("application/json", forHTTPHeaderField: "Accept")
        self.addValue("utf-8", forHTTPHeaderField: "Accept-Charset")
    }

    static func livestreams(bu: SRGService.BusinessUnits = .srf) -> URLRequest {
        .init(endpoint: "audiometadata/v2/livestreams", query: ["bu": bu.parameterValue])
    }

    static func mediaComposition(for mediaID: String, bu: SRGService.BusinessUnits = .srf) -> URLRequest {
        .init(endpoint: "audiometadata/v2/mediaComposition/audios/\(mediaID)", query: ["bu": bu.parameterValue])
    }
}
