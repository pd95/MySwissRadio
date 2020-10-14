//
//  AudioController.swift
//  MyRadio
//
//  Created by Philipp on 07.10.20.
//

import Foundation
import AVKit
import MediaPlayer
import Combine

class AudioController: NSObject, ObservableObject {

    @Published var playerStatus: AVPlayerItem.Status = .unknown

    override init() {
        super.init()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }

        setupMediaPlayerCommands()
    }

    func setupMediaPlayerCommands() {
        print("setupMediaPlayerCommands")
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] _ in
            self.player.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            self.player.pause()
            return .success
        }
    }

    func setupNowPlaying(_ nowPlayingInfo: [String: Any]) {
        print("setupNowPlaying: \(nowPlayingInfo)")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func enterBackground() {
        print("AudioController.enterBackground")
    }

    func enterForeground() {
        print("AudioController.enterForeground")
    }


    private var player = AVPlayer()
    private var asset: AVURLAsset!
    private var playerItem: AVPlayerItem!
    private var cancellables = Set<AnyCancellable>()

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func pause() {
        player.pause()
    }

    func play(url: URL) {
        if asset?.url != url {
            playerItem = AVPlayerItem(url: url)
            playerItem.publisher(for: \.status)
                .sink(receiveValue: { [weak self] status in
                    guard let self = self else { return }

                    self.playerStatus = status

                    if status == .readyToPlay {
                        self.player.play()
                    }
                })
                .store(in: &cancellables)

            player.replaceCurrentItem(with: playerItem)
        }
        else {
            player.play()
        }
    }
}
