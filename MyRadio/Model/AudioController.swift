//
//  AudioController.swift
//  MyRadio
//
//  Created by Philipp on 07.10.20.
//

import Foundation
import AVKit
import MediaPlayer

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
    }

    func enterBackground() {
        print("AudioController.enterBackground")
    }

    func enterForeground() {
        print("AudioController.enterForeground")
        if player.currentItem != nil {
            print("  recovering audio session")
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
        }

        self.objectWillChange.send()
    }


    private var player = AVPlayer()
    private var playerItem: AVPlayerItem!
    private var playerItemContext = 0

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func start(url: URL) {
        playerItem = AVPlayerItem(url: url)
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)

        player.replaceCurrentItem(with: playerItem)
        player.play()
    }

    // KVO callback
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

        // Only handle observations for the playerItemContext
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }

        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            playerStatus = status
        }
    }
}
