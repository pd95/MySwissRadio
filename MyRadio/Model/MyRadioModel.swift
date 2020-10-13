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

class MyRadioModel: NSObject, ObservableObject {

    static let main = MyRadioModel()

    private override init() {
        super.init()
    }

    //MARK: - Access to model data and UI helpers

    @Published var streams: [Livestream] = SettingsStore.shared.streams {
        didSet {
            SettingsStore.shared.streams = streams
        }
    }

    @Published var buSortOrder: [BusinessUnit] = BusinessUnit.allCases

    func streams(for bu: BusinessUnit) -> [Livestream] {
        streams.filter({ $0.bu == bu})
    }

    func stream(withID streamID: String) -> Livestream? {
        streams.first(where: { $0.id == streamID })
    }

    //MARK: - Fetching data from NetworkClient

    private var cancellables = Set<AnyCancellable>()

    func refreshContent() {
        let networkClient = NetworkClient.shared

        let logger = Logger(subsystem: "MyRadioModel", category: "refreshContent")

        var streams = [Livestream]()

        logger.log("starting to refresh")
        let livestreamsPublisher: AnyPublisher<[Livestream], Never> = buSortOrder.publisher
            .flatMap({ SRGService.getLivestreams(client: networkClient, bu: $0.apiBusinessUnit) })
            .handleEvents(receiveOutput: { [weak self] (newStreams: [Livestream]) in
                streams.append(contentsOf: newStreams)

                DispatchQueue.main.async {
                    self?.streams = streams
                    logger.log("updated streams to show intermediate UI")
                }
            })
            .flatMap({ streams -> AnyPublisher<Livestream, Never> in
                Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({ (stream: Livestream) -> AnyPublisher<Livestream, Never> in
                SRGService.getMediaResource(client: networkClient, for: stream.id, bu: stream.bu.apiBusinessUnit)
                    .map { (streamUrls: [URL]) -> Livestream in
                        let index = streams.firstIndex(of: stream)!
                        streams[index].streams = streamUrls
                        return streams[index]
                    }
                    .eraseToAnyPublisher()
            })
            .collect()
            .handleEvents(receiveOutput: { [weak self] (updatedStreams: [Livestream]) in
                // Make sure UI is updated
                DispatchQueue.main.async {
                    self?.streams = streams
                    logger.log("updated streams to show final UI (without images)")
                }
                self?.updateSiriSearch(streams)
            })
            .eraseToAnyPublisher()

        livestreamsPublisher
            .flatMap({ (streams: [Livestream]) -> AnyPublisher<Livestream, Never> in
                Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({ (stream: Livestream) -> AnyPublisher<(stream: Livestream, image: UIImage?), Never> in
                SRGService.getImageResource(client: networkClient, for: stream.thumbnailImageURL)
                    .map { image -> (stream: Livestream, image: UIImage?) in
                        (stream: stream, image: image)
                    }
                    .eraseToAnyPublisher()
            })
            .sink(receiveCompletion: { completion in
                logger.log("completed with \(String(describing: completion))")
                self.updateSpotlight(for: streams)
            }, receiveValue: { [weak self] (value) in
                guard let image = value.image else {
                    logger.log("No valid image for \(String(describing: value.stream))")
                    return
                }
                try? value.stream.saveThumbnail(image)
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
                logger.log("saving thumbnail image for \(String(describing: value.stream))")
            })
            .store(in: &cancellables)
    }

    func enterBackground() {
        print("MyRadioModel.enterBackground")
        controller.enterBackground()
    }

    func enterForeground() {
        print("MyRadioModel.enterForeground")
        controller.enterForeground()
    }

    // MARK: - Playback control
    private var controller = AudioController()
    private var controllerObserver: AnyCancellable?
    @Published private var currentlyPlaying: Livestream?

    func isPlaying(stream: Livestream) -> Bool {
        currentlyPlaying == stream
    }

    func isLoading(stream: Livestream) -> Bool {
        currentlyPlaying == stream && controller.playerStatus == .unknown
    }

    func stop() {
        currentlyPlaying = nil
        controller.stop()
    }

    func play(_ stream: Livestream) {
        currentlyPlaying = stream
        if let url = stream.streams.first {
            controller.start(id: stream.id, url: url, title: stream.name)
            controller.setupNowPlaying(stream.nowPlayingInfo)
            controllerObserver = controller.objectWillChange.sink(receiveValue: {
                _ in
                print("controller state changed: \(self.controller.playerStatus.rawValue)")
                self.objectWillChange.send()
            })
            updateLastPlayed(for: stream)
        }
    }

    func togglePlay(_ stream: Livestream) {
        guard stream.isReady else {
            fatalError("Cannot play stream in unready state: \(stream)")
        }
        if isPlaying(stream: stream) {
            stop()
            print("togglePlay: stopped")
        }
        else {
            print("togglePlay: start playing \(stream)")
            play(stream)
            donatePlayActivity(stream)
        }
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
               let stream = stream(withID: itemIdentifier) {
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
        model.streams = [.example]
        return model
    }()
}
