//
//  MyRadioApp.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

@main
struct MyRadioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = MyRadioModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
        .onChange(of: scenePhase) { (newPhase) in
            if newPhase == .active {
                model.enterForeground()
            }
            else if newPhase == .background {
                model.enterBackground()
            }
        }
    }
}
