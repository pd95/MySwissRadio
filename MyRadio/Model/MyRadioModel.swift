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

    init() {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }

    //MARK: - Access to model data and UI helpers

    @Published var streams: [Livestream] = UserDefaults.myDefaults.getEncoded(forKey: "streams") ?? [] {
        didSet {
            try! UserDefaults.myDefaults.setEncoded(streams, forKey: "streams")
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

    // MARK: - Playback control
    @Published private var currentlyPlaying: Livestream?

    private var player = AVPlayer()
    private var currentItem: AVPlayerItem?

    func isPlaying(stream: Livestream) -> Bool {
        currentlyPlaying == stream
    }

    func togglePlay(_ stream: Livestream) {
        guard stream.isReady else {
            fatalError("Cannot play stream in unready state: \(stream)")
        }
        if currentlyPlaying == stream {
            currentlyPlaying = nil
            player.pause()
            player.replaceCurrentItem(with: nil)
            print("togglePlay: stopped")
        }
        else {
            if let url = stream.streams.first {
                currentlyPlaying = stream
                currentItem = AVPlayerItem(url: url)
                player.replaceCurrentItem(with: currentItem)
                player.play()
                print("togglePlay: start playing \(url)")
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
