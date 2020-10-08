//
//  MyRadioModel.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation
import Combine
import AVKit

class MyRadioModel: ObservableObject {

    //MARK: - Access to model data and UI helpers

    @Published var streams: [Livestream] = SettingsStore.shared.getEncodedData(forKey: "streams", from: .shared) ?? [] {
        didSet {
            try! SettingsStore.shared.setEncodedData(streams, forKey: "streams", in: .shared)
        }
    }

    @Published var buSortOrder: [BusinessUnit] = BusinessUnit.allCases

    func streams(for bu: BusinessUnit) -> [Livestream] {
        streams.filter({ $0.bu == bu})
    }


    //MARK: - Fetching data from NetworkClient

    private var cancellables = Set<AnyCancellable>()

    func refreshContent() {
        buSortOrder.publisher
            .flatMap({ SRGService.getLivestreams(client: NetworkClient.shared, bu: $0.apiBusinessUnit) })
            .handleEvents(receiveOutput: { [weak self] newStreams in
                DispatchQueue.main.async {
                    self?.streams.append(contentsOf: newStreams)
                }
            })
            .flatMap({ streams -> AnyPublisher<Livestream, Never> in
                Publishers.Sequence(sequence: streams)
                    .eraseToAnyPublisher()
            })
            .flatMap({ (stream: Livestream) -> AnyPublisher<Livestream?, Never> in
                SRGService.getMediaResource(client: NetworkClient.shared, for: stream.id, bu: stream.bu.apiBusinessUnit)
            })
            .compactMap({ $0 })
            .collect()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                print("refreshContent: \(completion)")
            }, receiveValue: { [weak self] newStreams in
                self?.streams = newStreams
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
