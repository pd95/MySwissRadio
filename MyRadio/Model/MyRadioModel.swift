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

class MyRadioModel: ObservableObject {

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

    func thumbnailImage(for stream: Livestream) -> UIImage? {
        // Check first in in-memory cache
        if let image = ImageCache.shared[stream.imageURL] {
            return image
        }

        // Then, check on file system in the shared cache
        let cacheURL = FileManager.sharedCacheLocation()
        let fileURL = cacheURL.appendingPathComponent("Stream-Thumbnail-\(stream.id).png")
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            ImageCache.shared[stream.imageURL] = image
            return image
        }
        return nil
    }

    private func saveThumbnail(_ image: UIImage?, for stream: Livestream) {
        if let data = image?.pngData() {
            let cacheURL = FileManager.sharedCacheLocation()
            let fileURL = cacheURL.appendingPathComponent("Stream-Thumbnail-\(stream.id).png")
            if let _ = try? data.write(to: fileURL, options: .atomicWrite) {
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
            else {
                print("Failed to save data to \(fileURL)")
            }
        }
    }

    //MARK: - Fetching data from NetworkClient

    private var cancellables = Set<AnyCancellable>()

    func refreshContent() {
        let networkClient = NetworkClient.shared

        let logger = Logger(subsystem: "MyRadioModel", category: "refreshContent")

        logger.log("starting to refresh")
        let livestreamsPublisher: AnyPublisher<[Livestream], Never> = buSortOrder.publisher
            .flatMap({ SRGService.getLivestreams(client: networkClient, bu: $0.apiBusinessUnit) })
            .handleEvents(receiveOutput: { [weak self] (newStreams: [Livestream]) in
                DispatchQueue.main.async {
                    self?.streams.append(contentsOf: newStreams)
                    logger.log("updated streams to show intermediate UI")
                }
            })
            .flatMap({ streams -> AnyPublisher<Livestream, Never> in
                Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({ (stream: Livestream) -> AnyPublisher<Livestream?, Never> in
                SRGService.getMediaResource(client: networkClient, for: stream.id, bu: stream.bu.apiBusinessUnit)
            })
            .compactMap({ (stream: Livestream?) -> Livestream? in stream })  // get rid of failed entries (=unwrap Livestream?)
            .collect()
            .handleEvents(receiveOutput: { [weak self] (updatedStreams: [Livestream]) in
                // Make sure UI is updated
                DispatchQueue.main.async {
                    self?.streams = updatedStreams
                    logger.log("updated streams to show final UI (without images)")
                }
            })
            .eraseToAnyPublisher()

        livestreamsPublisher
            .flatMap({ (streams: [Livestream]) -> AnyPublisher<Livestream, Never> in
                Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({ (stream: Livestream) -> AnyPublisher<(stream: Livestream, image: UIImage?), Never> in
                SRGService.getImageResource(client: networkClient, for: stream.imageURL(for: 400))
                    .map { image -> (stream: Livestream, image: UIImage?) in
                        (stream: stream, image: image)
                    }
                    .eraseToAnyPublisher()
            })
            .sink(receiveCompletion: { completion in
                logger.log("completed with \(String(describing: completion))")
            }, receiveValue: { [weak self](value) in
                self?.saveThumbnail(value.image, for: value.stream)
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

    func togglePlay(_ stream: Livestream) {
        guard stream.isReady else {
            fatalError("Cannot play stream in unready state: \(stream)")
        }
        if currentlyPlaying == stream {
            currentlyPlaying = nil
            controller.stop()
            print("togglePlay: stopped")
        }
        else {
            if let url = stream.streams.first {
                currentlyPlaying = stream
                controller.start(id: stream.id, url: url, title: stream.name)
                print("togglePlay: start playing \(url)")
                controllerObserver = controller.objectWillChange.sink(receiveValue: {
                    _ in
                    print("controller state changed: \(self.controller.playerStatus.rawValue)")
                    self.objectWillChange.send()
                })
            }
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
