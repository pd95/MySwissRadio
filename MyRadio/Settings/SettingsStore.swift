//
//  SettingsStore.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import Foundation
import Combine
import os.log

class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    private let logger = Logger(subsystem: "MyRadio", category: "SettingsStore")

    var anyCancellable: AnyCancellable?

    private init() {
        anyCancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self](x) in
                self?.logger.log("UserDefaults.didChangeNotification \(x.description)")
                self?.checkAndSetVersionAndBuildNumber()
            }
        checkAndSetVersionAndBuildNumber()
    }

    @UserDefault(key: UserDefaults.Keys.reset, defaultValue: false)
    var reset: Bool

    @UserDefault(key: UserDefaults.Keys.appVersion, defaultValue: "-")
    var appVersion: String

    // Utilities to store and retrieve `Codable` data in UserDefaults
    func setEncodedData<T>(_ encodable: T, forKey key: String, in storage: UserDefaults = .standard) throws where T: Codable {
        let data = try JSONEncoder().encode(encodable)
        storage.setValue(data, forKey: key)
    }

    func getEncodedData<T>(forKey key: String, from storage: UserDefaults = .standard) -> T? where T: Codable {
        guard let data = storage.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func checkAndSetVersionAndBuildNumber() {
        if reset {
            resetAll()
        }
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let build: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        let currentVersion = "\(version) (\(build))"
        if appVersion != currentVersion {
            appVersion = currentVersion
        }
    }

    private func resetAll() {
        logger.log("Resetting all settings for \(UserDefaults.sharedSuiteName) and \(UserDefaults.currentSuiteName)")
        UserDefaults.standard.removePersistentDomain(forName: UserDefaults.sharedSuiteName)
        UserDefaults.standard.removePersistentDomain(forName: UserDefaults.currentSuiteName)
    }
}

extension UserDefaults {
    static let currentSuiteName = Bundle.main.bundleIdentifier!
    static let sharedSuiteName = "MyRadio"
    static let shared = UserDefaults(suiteName: sharedSuiteName)!

    fileprivate struct Keys {
        static let reset = "reset"
        static let appVersion = "appVersion"
    }
}
