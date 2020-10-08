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
            .flatMap({ NetworkClient.shared.getLivestreams(bu: $0.apiBusinessUnit) })
            .collect()
            .map { Array($0.joined().sorted()) }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                print("refreshContent: \(completion)")
                switch completion {
                    case .failure(let error):
                        print("refreshContent: error \(error)")
                    case .finished:
                        break
                }
            }, receiveValue: { [weak self] newStreams in
                self?.streams = newStreams
                self?.fetchMediaURL(for: newStreams)
            })
            .store(in: &cancellables)
    }

    private func fetchMediaURL(for streams: [Livestream]) {
        streams.publisher
            .flatMap({ stream -> AnyPublisher<Livestream?, Never> in
                return NetworkClient.shared.getMediaResource(for: stream.id, bu: stream.bu.apiBusinessUnit)
            })
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                print("fetchMediaURL: \(completion)")
                if case .failure(let error) = completion {
                    print("fetchMediaURL: \(error)")
                }

            }, receiveValue: { [weak self] newStream in
                guard let self = self,
                      let newStream = newStream
                else {
                    return
                }

                var newStreams = self.streams
                if let index = newStreams.firstIndex(where: {
                    $0.id == newStream.id && $0.bu == newStream.bu
                }) {
                    newStreams[index] = newStream
                }
                else {
                    newStreams.append(newStream)
                }
                self.streams = newStreams
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
