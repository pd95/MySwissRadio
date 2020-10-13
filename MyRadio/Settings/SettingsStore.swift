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
        //reset = true
        checkAndSetVersionAndBuildNumber()
    }

    @UserDefault(key: .reset, defaultValue: false)
    var reset: Bool

    @UserDefault(key: .appVersion, defaultValue: "-")
    var appVersion: String

    @CodableUserDefault(key: .streams, defaultValue: [], storage: .shared)
    var streams: [Livestream]

    @UserDefault(key: .searchWords, defaultValue: [:], storage: .shared)
    var wordToStreamsMap: [String:[Livestream.ID]]

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
        self.objectWillChange.send()
        UserDefaults.standard.removePersistentDomain(forName: UserDefaults.sharedSuiteName)
        UserDefaults.standard.removePersistentDomain(forName: UserDefaults.currentSuiteName)
    }
}

extension UserDefaults {
    static let currentSuiteName = Bundle.main.bundleIdentifier!
    static let sharedSuiteName = Bundle.appGroupIdentifier
    static let shared = UserDefaults(suiteName: sharedSuiteName)!

    enum SettingsKey: String, CaseIterable {
        case reset
        case appVersion
        case streams
        case searchWords
    }

    func removeObject(forKey settingsKey: SettingsKey) {
        removeObject(forKey: settingsKey.rawValue)
    }

    /// Get or set a value for a `SettingsKey`.
    ///
    /// `get`: `nil` if a retrieved object cannot be cast to `Value`.
    ///
    /// `set`: Equivalent to calling `removeObject`  if `newValue` is `nil`.
    subscript<Value>(key: SettingsKey) -> Value? {
        get { object(forKey: key.rawValue) as? Value }
        set { set(newValue, forKey: key.rawValue) }
    }
}
