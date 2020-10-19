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

    enum Status {
        case undefined, paused, playing, loading
    }

    var playerStatus: Status {
        if player.rate == 0 {
            return .paused
        }
        else if player.rate == 1 {
            if player.status == .readyToPlay {
                return .playing
            }
            else {
                return .loading
            }
        }
        else {
            return .undefined
        }
    }

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

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
    }

    func setupNowPlaying(_ nowPlayingInfo: [String: Any]) {
        print("setupNowPlaying: \(nowPlayingInfo)")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }


    private var player = AVPlayer()
    private var asset: AVURLAsset!
    private var playerItem: AVPlayerItem!

    func stop() {
        player.rate = 0
        player.replaceCurrentItem(with: nil)
        statusChanged()
    }

    func pause() {
        player.rate = 0
        statusChanged()
    }

    func play(url: URL? = nil) {
        if let url = url, asset?.url != url {
            asset = AVURLAsset(url: url)
            playerItem = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: playerItem)
        }
        player.rate = 1.0
        statusChanged()
    }

    func statusChanged() {
        objectWillChange.send()
    }
}
