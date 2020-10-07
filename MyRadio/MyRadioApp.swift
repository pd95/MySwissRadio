//
//  MyRadioApp.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

@main
struct MyRadioApp: App {
    @StateObject private var model = MyRadioModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
