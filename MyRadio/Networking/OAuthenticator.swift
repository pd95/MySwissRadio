//
//  OAuthenticator.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import os.log

///
/// `OAuthConfiguration` is the configuration object defining the `OAuthenticator` behaviour.
///
/// As only "Client Credentials" mode is supported, only three parameters are mandatory:
///   - `authorizationURL`
///   - `clientKey`
///   - `clientSecret`
///
/// If `userDefaultsKey` is specified, the last authorization response is fully cached.
///
/// To ensure that the `clientKey`and `clientSecret` do not have to be hardcoded in source code
/// the configuration object can be load from a JSON resource using `init(fromJSONResource:, in:)`
/// or from the bundle property list using `init(fromBundle:, prefix:)`.
///
struct OAuthConfiguration: Codable {

    fileprivate let authorizationURL: URL
    fileprivate let clientKey: String
    fileprivate let clientSecret: String

    fileprivate let userDefaultsKey: String?
    fileprivate let userDefaultsSuiteName: String?
    fileprivate var urlSession: URLSession = .shared

    enum CodingKeys: CodingKey {
        case authorizationURL, clientKey, clientSecret, userDefaultsKey, userDefaultsSuiteName
    }

    /// Creates a configuration object using the given parameters
    /// - Parameters:
    ///   - authorizationURL: URL of the authorization end point. The URL should include the `grant_type=client_credentials` parameter
    ///   - clientKey: The client key, known to the authorization end point
    ///   - clientSecret: The client secret known to the authorization end point
    ///   - userDefaultsKey: a key used to store (and fetch upon reinitialisation) the last authorization response from `UserDefaults`
    public init(authorizationURL: URL, clientKey: String, clientSecret: String, userDefaultsKey: String? = nil, userDefaultsSuiteName: String? = nil, urlSession: URLSession = .shared) {
        self.authorizationURL = authorizationURL
        self.clientKey = clientKey
        self.clientSecret = clientSecret
        self.userDefaultsKey = userDefaultsKey
        self.userDefaultsSuiteName = userDefaultsSuiteName
    }

    ///
    /// Creates a configuration object from a JSON encoded resource file
    ///
    /// - Parameters:
    ///   - resourceName: name of the resource file
    ///   - bundle: alternate bundle object, default is `Bundle.main`
    ///
    ///   Example JSON file:
    /// ```json
    ///{
    ///     "authorizationURL": "https://api.example.com/auth/accesstoken?grant_type=client_credentials",
    ///     "clientKey": "ABC123DEF567",
    ///     "clientSecret": "kQ4Mr5A9JD",
    ///     "userDefaultsKey": "MyApp.authResponse"
    ///}
    /// ```
    ///
    public init(fromJSONResource resourceName: String, in bundle: Bundle = .main, urlSession: URLSession = .shared) {
        let fileUrl = bundle.url(forResource: resourceName, withExtension: nil, subdirectory: nil)!
        do {
            let data = try Data(contentsOf: fileUrl)
            var instance = try JSONDecoder().decode(OAuthConfiguration.self, from: data)
            instance.urlSession = urlSession
            self = instance
        } catch {
            fatalError("Error loading \(resourceName): \(error.localizedDescription)")
        }
    }

    /// Creates a configuration object based on properties in the bundle configuration
    ///
    /// - Parameters:
    ///   - bundle: bundle object, default is `Bundle.main`
    ///   - prefix: property key prefix, e.g. `"MY_API_"`
    ///
    /// By default the property keys are:
    ///  - `AUTH_URL` **mandatory**
    ///  - `AUTH_KEY` **mandatory**
    ///  - `AUTH_SECRET` **mandatory**
    ///  - `AUTH_DEFAULTS_KEY` _optional_
    ///
    /// The optional prefix parameter is used to modify above keys, for example to `MY_API_AUTH_URL`.
    ///
    public init(fromBundle bundle: Bundle = .main, prefix: String = "", urlSession: URLSession = .shared) {
        let clientKey = bundle.object(forInfoDictionaryKey: "\(prefix)AUTH_KEY") as! String
        let clientSecret = bundle.object(forInfoDictionaryKey: "\(prefix)AUTH_SECRET") as! String
        let userDefaultsKey = bundle.object(forInfoDictionaryKey: "\(prefix)AUTH_DEFAULTS_KEY") as? String
        let userDefaultsSuiteName = bundle.object(forInfoDictionaryKey: "\(prefix)AUTH_DEFAULTS_SUITE") as? String

        let authorizationURL: URL
        if let authUrlString = bundle.object(forInfoDictionaryKey: "\(prefix)AUTH_URL") as? String, !authUrlString.isEmpty,
           let authUrl = URL(string: authUrlString.hasPrefix("https://") ? authUrlString : "https://\(authUrlString)") {
                authorizationURL = authUrl
        }
        else {
            fatalError("\(prefix)AUTH_URL configuration missing in bundle \(bundle.bundlePath)")
        }

        self.init(authorizationURL: authorizationURL, clientKey: clientKey, clientSecret: clientSecret, userDefaultsKey: userDefaultsKey, userDefaultsSuiteName: userDefaultsSuiteName, urlSession: urlSession)
    }


    fileprivate var persistedData: Data? {
        if let userDefaultsKey = userDefaultsKey {
            return UserDefaults(suiteName: userDefaultsSuiteName)?.data(forKey: userDefaultsKey)
        }
        return nil
    }

    fileprivate func persist(data: Data?) {
        if let userDefaultsKey = userDefaultsKey {
            UserDefaults(suiteName: userDefaultsSuiteName)?.setValue(data, forKey: userDefaultsKey)
        }
    }
}


class OAuthenticator {
    private let logger = Logger(subsystem: "MyRadio", category: "OAuthenticator")

    private let serialQueue = DispatchQueue.init(label: "OAuthenticator.serial")

    private let configuration: OAuthConfiguration

    private var refreshCancellable: AnyCancellable?

    private var currentToken: TokenState = .invalid {
        didSet {
            tokenSubject.send(currentToken)
        }
    }

    /// `CurrentValueSubject` which can be used to subscribe to the current access token
    var tokenSubject = CurrentValueSubject<TokenState, Never>(.invalid)

    public enum TokenState: CustomStringConvertible {
        case invalid
        case refreshFailed(error: Error)
        case valid(value: String, lastResponse: AccessTokenResponse)

        public var description: String {
            switch self {
                case .invalid:
                    return "invalid"
                case .refreshFailed(let error):
                    return "refreshFailed(error: \(error.localizedDescription))"
                case .valid(let value, _):
                    return "valid(value: \(value))"
            }
        }
    }

    public struct AccessTokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let expiresIn: String?
        let refreshToken: String?
        let scope: String?
    }

    public enum AuthError: Error {
        case invalidResponse
        case unexpectedHttpStatus(httpStatus: Int, error: String)
    }

    /// Initializes the authenticator with a given configuration
    /// - Parameter configuration: relevant configuration
    ///
    /// If the configuration specifies a `userDefaultsKey` the previous access token is restored. Otherwise the token starts out as invalid and must be refreshed upon first use.
    init(configuration: OAuthConfiguration) {
        self.configuration = configuration

        // Try to restore last access token response from UserDefaults
        if let lastResponseData = configuration.persistedData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let loadedToken = try? decoder.decode(AccessTokenResponse.self, from: lastResponseData) {
                currentToken = .valid(value: loadedToken.accessToken, lastResponse: loadedToken)
                logger.debug("Successfully restored token: \(self.currentToken)")
            }
        }
    }

    /// Invalidates the current token and triggers the subject
    func invalidateToken() {
        logger.debug("invalidateToken (\(self.currentToken))")
        configuration.persist(data: nil)
        currentToken = .invalid
    }

    /// Refreshes the access token by calling the configured OAuth endpoint with the client credentials
    /// - Parameters:
    ///   - delay: optional delay, before the token refresh call starts
    ///
    /// Even though `refreshToken` can be called in parallel by multiple sessions, only a single refresh process is running.
    /// All other calls are going to return without doing anything.
    func refreshToken(delay: TimeInterval = 0.0) {
        logger.debug("refreshToken (\(self.currentToken)) 🔸")

        logger.debug("refreshToken: right before entering critical section")
        serialQueue.sync {
            logger.debug("refreshToken: entered critical section")
            if case TokenState.valid(_, _) = self.currentToken {
                logger.debug("refreshToken: skipping, token already valid. Should receive current token (\(self.currentToken)) momentarily")
            }
            else if refreshCancellable == nil {
                refreshCancellable = performRefresh(delay: delay)
                    .receive(on: serialQueue)
                    .sink(receiveCompletion: { [weak self] (completion) in
                        self?.refreshCancellable = nil
                        switch completion {
                            // This case should never happen because we "catch" the errors and convert them just above
                            case .failure(let error):
                                self?.logger.error("performRefresh: error occured: \(error.localizedDescription)")

                            case .finished:
                                self?.logger.debug("performRefresh: done")
                                break
                        }
                    }, receiveValue: { [weak self](token) in
                        guard let self = self else { return }

                        // Store current token and trigger the given subject
                        self.logger.debug("performRefresh: sending new token \(token)")
                        self.currentToken = token
                    })
            }
            else {
                logger.debug("refreshToken: skipping refresh as there is already one ongoing")
            }

            logger.debug("refreshToken: leaving critical section 🔹")
        }
    }

    private func performRefresh(delay: TimeInterval) -> AnyPublisher<TokenState, Never> {

        logger.log("performRefresh: performing network request 🟡")

        // Prepare the authorization request with the client credentials in the header
        var request = URLRequest(url: configuration.authorizationURL,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: TimeInterval(10))

        let credentials = "\(configuration.clientKey):\(configuration.clientSecret)".data(using: .ascii)!.base64EncodedString()
        request.addValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")


        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

        if delay > 0.0 {
            logger.error("performRefresh: delay \(delay)s")
        }

        // Here starts the refresh request handling...
        return Just(1)
            .delay(for: .seconds(delay), scheduler: serialQueue)
            .flatMap { _ -> URLSession.DataTaskPublisher in
                URLSession.shared.dataTaskPublisher(for: request)
            }
            .tryMap { [weak self] data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.logger.error("performRefresh: invalidHttpResponse")
                    throw AuthError.invalidResponse
                }
                self?.logger.debug("performRefresh: response code \(httpResponse.statusCode)")
                if !(200..<400).contains(httpResponse.statusCode) {

                    // Try to extract the error code from the response body
                    let errorResponseArray = try? jsonDecoder.decode([String:String].self, from: data)
                    self?.logger.error("performRefresh: responseArray: \(errorResponseArray?.description ?? "-")")

                    let errorCode = errorResponseArray?["ErrorCode"] ??
                        errorResponseArray?["errorCode"] ??
                        errorResponseArray?["error_code"]

                    let errorDescription = errorResponseArray?["ErrorDescription"] ?? errorResponseArray?["errorDescription"] ?? errorResponseArray?["error_description"] ?? errorResponseArray?["Error"] ?? errorResponseArray?["error"]

                    self?.logger.error("performRefresh: errorCode = \(errorCode ?? "-") errorDescription = \(errorDescription ?? "-")")

                    throw AuthError.unexpectedHttpStatus(httpStatus: httpResponse.statusCode,
                                                         error: errorDescription ?? errorCode ?? "n/a")
                }

                // Store response if requested
                if data.count > 0 {
                    self?.logger.debug("performRefresh: storing raw accessTokenResponse 🟢 \(String(data: data, encoding: .utf8) ?? "-")")
                    self?.configuration.persist(data: data)
                }
                return data
            }
            .decode(type: AccessTokenResponse.self, decoder: jsonDecoder)
            .map { response -> TokenState in
                TokenState.valid(value: response.accessToken, lastResponse: response)
            }
            .catch({ (error: Error) -> AnyPublisher<TokenState, Never> in
                self.logger.debug("performRefresh: retryFailed with error \(error.localizedDescription)")
                return Just(TokenState.refreshFailed(error: error))
                    .eraseToAnyPublisher()
            })
            .eraseToAnyPublisher()
    }
}
