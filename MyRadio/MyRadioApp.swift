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
        logger.log("ApplicationDelegate didFinishLaunchingWithOptions. \(String(describing: launchOptions?.keys))")

// It is unclear whether we really have to request Siri authorization. Everything works fine so far without it!?
//        INPreferences.requestSiriAuthorization { (authStatus: INSiriAuthorizationStatus) in
//            self.logger.log("SiriAutorization: \(String(describing: authStatus))")
//        }
//
        return true
    }

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        logger.log("ApplicationDelegate handlerFor intent: \(intent)")
        return MyRadioModel.main
    }
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
