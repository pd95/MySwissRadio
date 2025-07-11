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

@MainActor
class MyRadioModel: NSObject, ObservableObject {

    static let main = MyRadioModel()

    private(set) var streamStore = LivestreamStore(SettingsStore.shared.streams)
    private let logger = Logger(subsystem: "MyRadioModel", category: "General")

    private override init() {
        super.init()

        if currentlyPlaying == nil,
           let lastPlayedStreamID = SettingsStore.shared.lastPlayedStreamId,
           let stream = streamStore.stream(withID: lastPlayedStreamID) {
            logger.log("Last played stream \(stream.name, privacy: .public): prepare UI in paused mode")
            play(stream, initiallyPaused: true)
            showSheet = true
        }

        // Make sure we propagate any change of the streams as "our own" change
        streamStore.$streams
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { _ in
                self.logger.log("streamStore changed, notifying UI")
                self.objectWillChange.send()
            })
            .store(in: &cancellables)
    }

    // MARK: - Access to model data and UI helpers

    var buSortOrder: [BusinessUnit] { BusinessUnit.allCases }

    @Published var showSheet = false

    // MARK: - Fetching data from NetworkClient

    private var cancellables = Set<AnyCancellable>()

    func refreshContent() async {
        let logger = Logger(subsystem: "MyRadioModel", category: "refreshContent")

        let refreshStartDate = Date()
        logger.log("starting to refresh (last refresh was \(SettingsStore.shared.lastLivestreamRefreshDate, privacy: .public))")

        let streams = await streamStore.refreshLivestreams()

        SettingsStore.shared.streams = streams
        SettingsStore.shared.lastLivestreamRefreshDate = refreshStartDate
        updateSiriSearch(streams)
        updateWidgets()
        objectWillChange.send()

        logger.log("updated streams to show UI (with some images)")
    }

    func updateWidgets() {
        logger.debug("updateWidgets")
        WidgetCenter.shared.reloadTimelines(ofKind: "MyRadioWidgets")
    }

    func enterBackground() {
        logger.debug("enterBackground")

        cancelUITimer()
    }

    func enterForeground() {
        logger.debug("enterForeground")
        let lastRefresh = SettingsStore.shared.lastLivestreamRefreshDate
        let timeSinceLastRefresh = lastRefresh.distance(to: Date())
        logger.log("Last refresh \(lastRefresh, privacy: .public) => \(timeSinceLastRefresh)s ago")
        if SettingsStore.shared.streams.isEmpty || timeSinceLastRefresh > 30*24*60*60 {
            Task {
                await refreshContent()
            }
        }

        // Unfreeze the player (if the user paused long ago)
        controller.unfreezePlayer()

        // Restore time (if it was running previously)
        if uiUpdateTimer != nil {
            setupUITimer()
        }
    }

    // MARK: - UI State
    @Published var uiUpdateTimer: AnyCancellable?
    @Published var seekRange = 0.0...1.0
    @Published var currentPosition: Double = 0.0
    @Published var currentDate: Date = Date()

    func setupUITimer() {
        logger.debug("Setup UI update timer")
        uiUpdateTimer = Timer.publish(every: 1, on: .current, in: .common)
            .autoconnect()
            .sink(receiveValue: { [weak self] _ in
                self?.updateState()
            })
        updateState()
    }

    func cancelUITimer() {
        uiUpdateTimer?.cancel()
    }

    func removeUITimer() {
        uiUpdateTimer = nil
    }

    func updateState() {
        guard controller.playerStatus != .undefined else { return }

        let date = controller.currentDate
        logger.debug("updateState \(date.localizedTimeString, privacy: .public)")
        currentDate = date
        seekRange = controller.seekRange
        currentPosition = controller.currentPosition
    }

    var playerIsInitialized: Bool {
        controller.playerStatus != .undefined
    }

    var earliestSeekDate: Date {
        controller.earliestSeekDate
    }

    var relativeOffsetToLive: TimeInterval {
        controller.relativeOffsetToLive
    }

    var isLive: Bool {
        controller.isLive
    }

    func togglePlayPause() {
        guard let stream = currentlyPlaying else { return }
        togglePlay(stream)
        updateState()
    }

    func seekToLive() {
        controller.seekToLive()
        updateState()
    }

    func stepBackward() {
        controller.stepBackward()
        updateState()
    }

    func stepForward() {
        controller.stepForward()
        updateState()
    }

    func seekToCurrentPosition() {
        controller.currentPosition = currentPosition
        updateState()
    }

    // MARK: - Playback control
    var controller = AudioController()
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

    func play(_ stream: Livestream, initiallyPaused: Bool = false) {
        logger.debug("play(\(stream, privacy: .public), initiallyPaused: \(initiallyPaused)")
        currentlyPlaying = stream
        if let url = stream.streams.first {
            controller.play(url: url, initiallyPaused: initiallyPaused)
            controller.setupNowPlaying(stream.nowPlayingInfo)

            SettingsStore.shared.lastPlayedStreamId = stream.id
            SettingsStore.shared.isPlaying = true

            var oldStatus: AudioController.Status?

            controllerObserver = controller.objectWillChange
                .sink(receiveValue: { _ in
                    let status = self.controller.playerStatus

                    if oldStatus != status {
                        self.logger.debug("controller state changed: \(status.debugDescription, privacy: .public)")
                        if status == .playing {
                            self.isPaused = false
                            self.streamStore.updateLastPlayed(for: stream, date: Date())
                        } else {
                            self.isPaused = true
                        }
                        SettingsStore.shared.isPlaying = !self.isPaused
                        self.updateWidgets()
                        oldStatus = status
                    }
                })
        }
    }

    func togglePlay(_ stream: Livestream) {
        guard stream.isReady else {
            fatalError("Cannot play stream in unready state: \(stream)")
        }
        if isPlaying(stream: stream) {
            pause()
            logger.debug("togglePlay: paused")
        } else {
            logger.debug("togglePlay: start playing \(stream, privacy: .public)")
            play(stream)
            donatePlayActivity(stream)
        }
        showSheet = true
    }

    // MARK: - "Siri intelligence"

    func donatePlayActivity(_ stream: Livestream) {
        let intent = INPlayMediaIntent(mediaItems: [stream.mediaItem])

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { (error) in
            if let error = error {
                self.logger.error("Unable to donate \(intent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            } else {
                self.logger.debug("Successfully donated playActivity")
            }
        }
    }

    func handleActivity(_ userActivity: NSUserActivity) {

        let logger = Logger(subsystem: "MyRadioModel", category: "handleActivity")

        if let intent = userActivity.interaction?.intent {
            logger.debug("handleActivity: intent=\(intent, privacy: .public)")
            // Based on intent (Siri or from Widget)
            if handlePlayIntent(intent) == nil {
                logger.error("Error while handling \(userActivity, privacy: .public)")
            }
        } else if userActivity.activityType == CSSearchableItemActionType {
            // Based on Spotlight search result: toggle playing of selected stream
            if let itemIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let stream = streamStore.stream(withID: itemIdentifier) {
                logger.debug("handleActivity: spotlight selected \(stream, privacy: .public)")
                togglePlay(stream)
            } else {
                logger.error("Invalid spotlight item: \(userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, privacy: .public)")
            }
        } else {
            logger.error("Invalid activity: \(userActivity, privacy: .public)")
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
