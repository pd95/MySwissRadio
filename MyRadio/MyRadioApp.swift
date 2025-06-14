//
//  MyRadioApp.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI
import os.log
import Intents
import CoreSpotlight

class AppDelegate: NSObject, UIApplicationDelegate {
    let logger = Logger(subsystem: "MyRadio", category: "AppDelegate")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        logger.log("ApplicationDelegate didFinishLaunchingWithOptions. \(String(describing: launchOptions?.keys), privacy: .public)")

        #if DEBUG
        backupSettings()
        // authconfigapplySettings()
        #endif

// It is unclear whether we really have to request Siri authorization. Everything works fine so far without it!?
//        INPreferences.requestSiriAuthorization { (authStatus: INSiriAuthorizationStatus) in
//            self.logger.log("SiriAutorization: \(String(describing: authStatus), privacy: .public)")
//        }
//
        return true
    }

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        logger.log("ApplicationDelegate handlerFor intent: \(intent, privacy: .public)")
        return MyRadioModel.main
    }

#if DEBUG
    private func backupSettings() {
        let date = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "")
        dumpUserDefaults(UserDefaults.standard, filename: "userdefaults-standard-\(date)")
        dumpUserDefaults(UserDefaults.shared, filename: "userdefaults-shared-\(date)")
        dumpUserDefaults(UserDefaults(suiteName: "")!, filename: "userdefaults-authconfig-\(date)")
    }

    private func applySettings() {
        SettingsStore.shared.lastLivestreamRefreshDate = Date().addingTimeInterval(-31*24*60*60)  // expired!

        let response = OAuthenticator.AccessTokenResponse(
            accessToken: "ThisIsAnInvalidToken",
            tokenType: "Bearer",
            expiresIn: nil,
            refreshToken: nil,
            scope: nil
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try? encoder.encode(response)
        UserDefaults(suiteName: "")!.set(data ?? Data(), forKey: "AuthData")
    }

    private func dumpUserDefaults(_ defaults: UserDefaults, filename: String) {
        do {
            let dict = defaults.dictionaryRepresentation()
            if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("\(filename).plist")
                try data.write(to: url)
                logger.log("dumpUserDefaults: \(url, privacy: .public)")
            }
        } catch {
            logger.log("dumpUserDefaults: \(error.localizedDescription, privacy: .public)")
        }
    }
#endif
}

@main
struct MyRadioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = MyRadioModel.main

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onContinueUserActivity("ConfigurationIntent", perform: model.handleActivity)
                .onContinueUserActivity(CSSearchableItemActionType, perform: model.handleActivity)
        }
        .onChange(of: scenePhase) { (newPhase) in
            if newPhase == .active {
                model.enterForeground()
            } else if newPhase == .background {
                model.enterBackground()
            }
        }
    }
}
