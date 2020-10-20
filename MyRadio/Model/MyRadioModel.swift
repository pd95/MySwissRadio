//
//  MyRadioModel.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import os.log
import UIKit
import Intents
import CoreSpotlight
import WidgetKit

class MyRadioModel: NSObject, ObservableObject {

    static let main = MyRadioModel()

    private(set) var streamStore = LivestreamStore(SettingsStore.shared.streams)

    private override init() {
        super.init()

        if currentlyPlaying == nil, let stream = streamStore.stream(withID: SettingsStore.shared.lastPlayedStreamId ?? "") {
            play(stream)
            pause()
            showSheet = true
        }

        // Make sure we propagate any change of the streams as "our own" change
        streamStore.$streams
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { _ in self.objectWillChange.send() })
            .store(in: &cancellables)
    }

    //MARK: - Access to model data and UI helpers

    @Published var buSortOrder: [BusinessUnit] = BusinessUnit.allCases

    @Published var showSheet = false

    //MARK: - Fetching data from NetworkClient

    private var cancellables = Set<AnyCancellable>()

    func refreshContent() {
        let logger = Logger(subsystem: "MyRadioModel", category: "refreshContent")

        logger.log("starting to refresh")
        streamStore.refreshLivestreamPublisher()
            .sink(receiveCompletion: { completion in
                logger.log("completed with \(String(describing: completion))")
            }, receiveValue: { [weak self] (streams) in
                SettingsStore.shared.streams = streams
                self?.updateSpotlight(for: streams)
                self?.updateSiriSearch(streams)
                self?.updateWidgets()
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                    logger.log("updated streams to show UI (with some images)")
                }
            })
            .store(in: &cancellables)
    }

    func updateWidgets() {
        print("updateWidgets")
        WidgetCenter.shared.reloadTimelines(ofKind: "MyRadioWidgets")
    }

    func enterBackground() {
        print("MyRadioModel.enterBackground")
    }

    func enterForeground() {
        print("MyRadioModel.enterForeground")
        if SettingsStore.shared.streams.isEmpty {
            refreshContent()
        }
    }

    // MARK: - Playback control
    private var controller = AudioController()
    private var controllerObserver: AnyCancellable?
    @Published var currentlyPlaying: Livestream?
    @Published var isPaused: Bool = false

    func isPlaying(stream: Livestream) -> Bool {
        currentlyPlaying == stream && !isPaused
    }

    func isLoading(stream: Livestream) -> Bool {
        currentlyPlaying == stream && controller.playerStatus == .loading
    }

    func pause() {
        controller.pause()
        isPaused = true

        SettingsStore.shared.isPlaying = false
        updateWidgets()
    }

    func play(_ stream: Livestream) {
        currentlyPlaying = stream
        if let url = stream.streams.first {
            controller.play(url: url)
            controller.setupNowPlaying(stream.nowPlayingInfo)

            SettingsStore.shared.lastPlayedStreamId = stream.id
            SettingsStore.shared.isPlaying = true

            controllerObserver = controller.objectWillChange
                .sink(receiveValue: { _ in
                    let status = self.controller.playerStatus
                    print("controller state changed: \(status)")

                    if status == .playing {
                        self.isPaused = false
                        self.updateLastPlayed(for: stream)
                    }
                    else {
                        self.isPaused = true
                    }
                    SettingsStore.shared.isPlaying = !self.isPaused
                    self.updateWidgets()
                    self.objectWillChange.send()
                })
        }
    }

    func togglePlay(_ stream: Livestream) {
        guard stream.isReady else {
            fatalError("Cannot play stream in unready state: \(stream)")
        }
        if isPlaying(stream: stream) {
            pause()
            print("togglePlay: paused")
        }
        else {
            print("togglePlay: start playing \(stream)")
            play(stream)
            donatePlayActivity(stream)
        }
        showSheet = true
    }

    func donatePlayActivity(_ stream: Livestream) {
        let intent = INPlayMediaIntent(mediaItems: [stream.mediaItem])

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { (error) in
            if let error = error {
                print("Unable to donate \(intent): \(error)")
            }
            else {
                print("Successfully donated playActivity")
            }
        }
    }

    func handleActivity(_ userActivity: NSUserActivity) {

        let logger = Logger(subsystem: "MyRadioModel", category: "handleActivity")

        if let intent = userActivity.interaction?.intent {
            // Based on intent (Siri or from Widget)
            if handlePlayIntent(intent) == nil {
                logger.error("Error while handling \(userActivity)")
            }
        }
        else if userActivity.activityType == CSSearchableItemActionType {
            // Based on Spotlight search result: toggle playing of selected stream
            if let itemIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let stream = streamStore.stream(withID: itemIdentifier) {
                togglePlay(stream)
            }
            else {
                logger.error("Invalid spotlight item: \(userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String ?? "nil")")
            }
        }
        else {
            logger.error("Invalid activity: \(userActivity)")
        }
    }
}

extension MyRadioModel {
    static let example: MyRadioModel = {
        let model = MyRadioModel()
        model.streamStore = LivestreamStore([.example])
        return model
    }()
}
