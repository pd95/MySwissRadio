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

        setupRemoteTransportControls()
    }

    func setupRemoteTransportControls() {
        print("setupRemoteTransportControls")
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            print("playCommand")
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            print("pauseCommand")
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            print("togglePlayPauseCommand")
            self?.togglePlayPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            print("changePlaybackPositionCommand")
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            print(event.positionTime)
            self?.seek(to: event.positionTime)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(integerLiteral: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            print("skipBackwardCommand")
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self?.stepBackward(event.interval)
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(integerLiteral: 30)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            print("skipForwardCommand")
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self?.stepForward(event.interval)
            return .success
        }
    }

    func setupNowPlaying(_ nowPlayingInfo: [String: Any]) {
        print("setupNowPlaying: \(nowPlayingInfo)")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func enrichNowPlaying(duration: TimeInterval, position: Double, rate: Float) {
        print("enrichNowPlaying: duration=\(duration) position=\(position) rate=\(rate)")
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

        var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo ?? [String : Any]()

        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = (position + 10) > duration
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }


    private var player = AVPlayer()
    private var asset: AVURLAsset!
    private var playerItem: AVPlayerItem?
    private var playerItemCancellables = Set<AnyCancellable>()
    private var startTime: Date = .distantPast {
        didSet {
            print("🔴 startTime: \(DateFormatter.localizedString(from: startTime, dateStyle: .short, timeStyle: .full))")
        }
    }

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
            playerItem!.automaticallyPreservesTimeOffsetFromLive = true

            playerItemCancellables.removeAll()

            playerItem!.publisher(for: \.status)
                .removeDuplicates()
                .sink { [weak self] (status) in
                    guard let self = self else { return }
                    print("🟢 New status set: \(status.rawValue)")
                    if status == .readyToPlay {
                        self.startTime = Date().addingTimeInterval(-self.playerItem!.configuredTimeOffsetFromLive.seconds)
                        print("   startTime = \(self.startTime)")
                        print("   timebase  = \(self.playerItem?.timebase?.time.seconds ?? -1)")

                        self.statusChanged()
                    }
                }
                .store(in: &playerItemCancellables)

            playerItem!.publisher(for: \.seekableTimeRanges)
                .removeDuplicates()
                .sink { [weak self] (seekableTimeRanges) in
                    guard let self = self else { return }
                    print("🟢 New seekableTimeRanges set: \(seekableTimeRanges)")
                    if let firstRange = seekableTimeRanges.map({$0.timeRangeValue}).first {
                        print("   start:    \(firstRange.start.seconds)")
                        print("   duration: \(firstRange.duration.seconds)")

                        self.statusChanged()
                    }
                }
                .store(in: &playerItemCancellables)

            player.publisher(for: \.rate)
                .removeDuplicates()
                .sink { [weak self] (rate) in
                    guard let self = self else { return }
                    print("🔵 New rate set: \(rate)")
                    self.statusChanged()
                }
                .store(in: &playerItemCancellables)

            player.replaceCurrentItem(with: playerItem)
        }
        player.rate = 1.0
        statusChanged()
    }

    func togglePlayPause() {
        if player.rate != 1 {
            play()
        }
        else {
            pause()
        }
    }

    func statusChanged() {
        objectWillChange.send()

        if let currentItem = playerItem {
            let range = seekRange
            enrichNowPlaying(duration: range.upperBound-range.lowerBound, position: currentItem.currentTime().seconds-range.lowerBound, rate: player.rate)
        }
        dumpState()
    }


    func dumpState() {

        print("playerStatus: \(playerStatus)")
        print("playerItem: \(playerItem.debugDescription)")

        guard let playerItem = playerItem else { return }
        let asset = playerItem.asset
        print("asset: \(asset.debugDescription)")
        print("  duration: \(asset.duration.seconds)  overallDurationHint: \(asset.overallDurationHint.seconds)")
        print("  minimumTimeOffsetFromLive: \(asset.minimumTimeOffsetFromLive.seconds)")

        let currentTime = playerItem.currentTime()
        print("🟡 currentTime.seconds: \(currentTime.seconds)")

        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first,
           let loadedTimeRange = playerItem.loadedTimeRanges.map({ $0.timeRangeValue }).first {
            print("🟡 seekableTimeRange: start \(seekableTimeRange.start.seconds) end \(seekableTimeRange.end.seconds) duration \(seekableTimeRange.duration.seconds)")
            print("   loadedTimeRange:   start \(loadedTimeRange.start.seconds) end \(loadedTimeRange.end.seconds) duration \(loadedTimeRange.duration.seconds)")

            let earliestPosition = startTime.addingTimeInterval(seekableTimeRange.start.seconds - seekableTimeRange.duration.seconds)
            print("   earliestPosition: \(earliestPosition.localizedTimeString)")
            let newestPosition = startTime.addingTimeInterval(seekableTimeRange.end.seconds - seekableTimeRange.duration.seconds)
            print("   newestPosition: \(newestPosition.localizedTimeString)")
            let currentPosition = startTime.addingTimeInterval(currentTime.seconds - seekableTimeRange.duration.seconds)
            print("   currentPosition: \(currentPosition.localizedTimeString)")

            print("   [\(seekableTimeRange.start.seconds) \(currentTime.seconds) \(seekableTimeRange.end.seconds)] \(currentTime.seconds > seekableTimeRange.end.seconds ? "🔴" : "")")
            print("   [\(loadedTimeRange.start.seconds) \(currentTime.seconds) \(loadedTimeRange.end.seconds)] \(loadedTimeRange.end.seconds - currentTime.seconds)")
        }
    }

    func seek(to seconds: Double) {
        guard let playerItem = playerItem,
              let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first
        else {
            return
        }
        let newTime = CMTime(seconds: min(max(seconds, seekableTimeRange.start.seconds), seekableTimeRange.end.seconds), preferredTimescale: CMTimeScale(1))
        print("🟣 Seek to \(seconds) => newTime = \(newTime.seconds)")
        playerItem.cancelPendingSeeks()
        playerItem.seek(to: newTime, completionHandler: { (finished) in
            print(" >>> 🟣 Seek finished: Now at \(playerItem.currentTime().seconds)")
            self.statusChanged()
        })
    }

    func stepBackward(_ count: Double = 15) {
        seek(to: currentTime - count)
    }

    func stepForward(_ count: Double = 30) {
        seek(to: currentTime + count)
    }


    var earliestSeekDate: Date {
        guard let playerItem = playerItem else { return .distantPast }
        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first {
            return startTime.addingTimeInterval(seekableTimeRange.start.seconds - seekableTimeRange.duration.seconds)
        }
        return startTime
    }

    var currentTime: Double {
        get {
            playerItem?.currentTime().seconds ?? .zero
        }
        set {
            seek(to: newValue)
        }
    }

    var seekRange: ClosedRange<Double> {
        guard let playerItem = playerItem,
              let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first
        else {
            return 0...0
        }
        return seekableTimeRange.start.seconds...seekableTimeRange.end.seconds
    }

    var currentDate: Date {
        guard let playerItem = playerItem else { return .distantFuture }
        let currentTime = playerItem.currentTime()
        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first {
            return startTime.addingTimeInterval(currentTime.seconds - seekableTimeRange.duration.seconds)
        }
        return startTime
    }

    func relativeSecondsToDate(_ seconds: Double) -> Date {
        guard let playerItem = playerItem else { return startTime }
        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first {
            return startTime.addingTimeInterval(seconds - seekableTimeRange.duration.seconds)
        }
        return startTime
    }

    var relativeOffsetToLive: TimeInterval {
        guard let playerItem = playerItem else { return .zero }
        let currentTime = playerItem.currentTime()
        if let loadedTimeRange = playerItem.loadedTimeRanges.map({ $0.timeRangeValue }).first,
           let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first
        {
            let biggest = max(loadedTimeRange.end.seconds, seekableTimeRange.end.seconds)
            if biggest > currentTime.seconds {
                return TimeInterval(currentTime.seconds - biggest)
            }
        }
        return TimeInterval.zero
    }
}
