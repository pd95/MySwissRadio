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
import os.log

class AudioController: NSObject, ObservableObject {

    enum Status: CustomDebugStringConvertible {
        case undefined, paused, playing, loading

        var debugDescription: String {
            switch self {
            case .undefined:
                return "undefined"
            case .paused:
                return "paused"
            case .playing:
                return "playing"
            case .loading:
                return "loading"
            }
        }
    }

    var playerStatus: Status {
        guard let playerItem = playerItem,
              playerItem.status == .readyToPlay,
              let seekRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first,
              seekRange.isValid && !seekRange.isEmpty
        else {
            logger.debug("🔴 undefined playerStatus")
            return .undefined
        }
        if player.rate == 0 {
            return .paused
        } else if player.rate == 1 {
            if player.status == .readyToPlay {
                return .playing
            } else {
                return .loading
            }
        } else {
            return .undefined
        }
    }

    private let logger = Logger(subsystem: "AudioController", category: "General")

    override init() {
        super.init()

        setupAudioSession()
        setupNotifications()
        setupRemoteTransportControls()
    }

    func setupAudioSession() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            logger.error("Failed to set audio session route sharing policy: \(error.localizedDescription, privacy: .public)")
        }
    }

    var interruptionDate: Date? {
        didSet {
            logger.debug("🔺🔺🔺 interruptionDate set to \(self.interruptionDate?.description, privacy: .public)")
        }
    }

    private var notificationSubscriber = Set<AnyCancellable>()

    private func setupNotifications() {
        let notificationCenter = NotificationCenter.default

        notificationCenter
            .publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] (notification) in
                guard let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                      let self = self
                else {
                    return
                }

                // Switch over the interruption type.
                switch type {

                // An interruption began. Update the UI as needed.
                case .began:
                    self.logger.log("⚫️ INTERRUPTION BEGAN")
                    self.interruptionDate = .now

                // An interruption ended. Resume playback, if appropriate.
                case .ended:
                    guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    self.logger.log("⚫️ INTERRUPTION ENDED: optionsValue = \(options.rawValue) playerStatus = \(self.playerStatus.debugDescription, privacy: .public)")
                    self.logger.log("   interruptionDate = \(self.interruptionDate?.description, privacy: .public) lastRateChange = \(self.lastRateChange, privacy: .public)")
                    if options.contains(.shouldResume) {
                        // Interruption ended. Playback should resume.
                        self.logger.log("  Should resume playing.")
                        self.play()

                    } else {
                        // Interruption ended. Playback should not resume.
                        self.logger.log("  Should not resume.")
                    }

                // We do not know whether Apple will introduce new interruptions in the future
                default:
                    break
                }
            }
            .store(in: &notificationSubscriber)

        notificationCenter
            .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { _ in
                self.setupAudioSession()
            }
            .store(in: &notificationSubscriber)
    }

    private func setupRemoteTransportControls() {
        logger.debug("setupRemoteTransportControls")
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.logger.debug("playCommand")
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.logger.debug("pauseCommand")
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.logger.debug("togglePlayPauseCommand")
            self?.togglePlayPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            self?.logger.debug("changePlaybackPositionCommand")
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.logger.debug("target position = \(event.positionTime)")
            self?.seek(toOffsetFromStart: event.positionTime)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.logger.debug("skipBackwardCommand")
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self?.stepBackward(event.interval)
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(30)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.logger.debug("skipForwardCommand")
            guard let event = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            self?.stepForward(event.interval)
            return .success
        }
    }

    func setupNowPlaying(_ nowPlayingInfo: [String: Any]) {
        logger.debug("setupNowPlaying: \(nowPlayingInfo, privacy: .public)")
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

        var nowPlayingInfo = nowPlayingInfo
        if let url = (playerItem?.asset as? AVURLAsset)?.url {
            nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = url
        }
        nowPlayingInfo[MPMediaItemPropertyArtist] = "My radio"

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    private func enrichNowPlaying(duration: TimeInterval, position: Double, rate: Float) {
        logger.debug("enrichNowPlaying: isLive=\(self.isLive) duration=\(duration) position=\(position) rate=\(rate)")
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

        var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()

        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = isLive
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = rate
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo
    }

    private func removeNowPlaying() {
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        nowPlayingInfoCenter.nowPlayingInfo?.removeAll()
    }

    private var player = AVPlayer()
    private var playerItem: AVPlayerItem?
    private var playerItemCancellables = Set<AnyCancellable>()
    private var startTime: Date = .distantPast {
        didSet {
            logger.debug("🔴 startTime: \(DateFormatter.localizedString(from: self.startTime, dateStyle: .short, timeStyle: .full), privacy: .public)")
        }
    }
    private var lastRateChange: Date = .distantPast

    private let maxPausedDuration: TimeInterval = 10 * 60
    private let maxInterruptionDuration: TimeInterval = 2 * 60 * 60

    func stop() {
        player.rate = 0
        player.replaceCurrentItem(with: nil)
        playerItem = nil
        removeNowPlaying()
    }

    func pause() {
        player.rate = 0
    }

    func play(url: URL? = nil, initiallyPaused: Bool = false) {
        if let url = url, (playerItem?.asset as? AVURLAsset)?.url != url {
            logger.log("Setting AVPlayerItem to url=\(url)")
            let asset = AVURLAsset(url: url)

            playerItem = AVPlayerItem(asset: asset)
            playerItem!.automaticallyPreservesTimeOffsetFromLive = true

            playerItemCancellables.removeAll()

            playerItem!.publisher(for: \.status)
                .removeDuplicates()
                .sink { [weak self] (status: AVPlayerItem.Status) in
                    guard let self = self else { return }
                    self.logger.debug("🟢 New status set: \(status.debugDescription, privacy: .public)")
                    if status == .readyToPlay {
                        let offsetFromLive = self.playerItem!.configuredTimeOffsetFromLive.seconds
                        self.startTime = Date().addingTimeInterval(-offsetFromLive)
                        self.logger.debug("   startTime = \(self.startTime, privacy: .public)")
                        self.logger.debug("   timebase  = \(self.playerItem?.timebase?.time.seconds ?? -1)")
                        let newRate: Float = initiallyPaused ? 0.0 : 1.0
                        logger.log("setting rate \(newRate)")
                        self.player.rate = newRate

                        self.statusChanged("status")
                    } else if status == .failed, let error = self.playerItem?.error {
                        self.logger.debug("playerItem.status failed with error \(error.localizedDescription, privacy: .public)")
                    }
                }
                .store(in: &playerItemCancellables)

            playerItem!.publisher(for: \.seekableTimeRanges)
                .removeDuplicates()
                .sink { [weak self] (seekableTimeRanges) in
                    guard let self = self else { return }
                    self.logger.debug("🟢 New seekableTimeRanges set: \(seekableTimeRanges, privacy: .public)")
                    if let firstRange = seekableTimeRanges.map({$0.timeRangeValue}).first {
                        self.logger.debug("   start:    \(firstRange.start.seconds)")
                        self.logger.debug("   duration: \(firstRange.duration.seconds)")

                        self.statusChanged("seekableTimeRanges")
                    }
                }
                .store(in: &playerItemCancellables)

            player.publisher(for: \.rate)
                .removeDuplicates()
                .sink { [weak self] (rate) in
                    guard let self = self else { return }
                    self.logger.debug("🔵 New rate set: \(rate)")
                    self.lastRateChange = Date()
                    self.statusChanged("rate")
                }
                .store(in: &playerItemCancellables)

            player.replaceCurrentItem(with: playerItem)
        } else {
            let newRate: Float = initiallyPaused ? 0.0 : 1.0
            logger.log("no change of channel. Setting rate \(newRate)")
            if player.rate != newRate {
                player.rate = newRate
                playerItem!.automaticallyPreservesTimeOffsetFromLive = true
            }

            // Check latest interruption/pausing timestamp
            let changeDate = interruptionDate ?? lastRateChange
            let delta = changeDate.distance(to: Date())
            logger.log("changeDate: \(changeDate, privacy: .public) (\(delta) seconds ago)")
            if delta > maxInterruptionDuration {
                logger.log("change is more than \(self.maxInterruptionDuration/60) minutes in the past! Restarting stream")
                restartPlayer(initiallyPaused: initiallyPaused)
            } else if delta > maxPausedDuration {
                logger.log("interruption is more than \(self.maxPausedDuration/60) minutes in the past!")
                seekToLive()
            }
        }
        if interruptionDate != nil {
            interruptionDate = nil
        }
    }

    func togglePlayPause() {
        if player.rate != 1 {
            play()
        } else {
            pause()
        }
    }

    func unfreezePlayer() {
        logger.log("⚫️⚫️⚫️ unfreezePlayer")
        logger.log("  playerStatus=\(self.playerStatus.debugDescription, privacy: .public) lastRateChange=\(self.lastRateChange.localizedTimeString, privacy: .public) (=\(self.lastRateChange.distance(to: Date())) seconds ago)")

        if lastRateChange.distance(to: Date()) > maxInterruptionDuration {
            logger.log("Paused for more than \(self.maxInterruptionDuration/60) minutes, ")
            restartPlayer(initiallyPaused: playerStatus == .paused)
        }
    }

    func restartPlayer(initiallyPaused: Bool) {
        logger.log("restartPlayer")
        guard let url = (playerItem?.asset as? AVURLAsset)?.url else {
            logger.log("cannot restart when no URL has been playing")
            return
        }
        // Unfreeze state of player, by completely stopping and restarting the stream.
        stop()
        play(url: url, initiallyPaused: initiallyPaused)
    }

    func statusChanged(_ reasonString: String = "undefined") {
        objectWillChange.send()

        if let currentItem = playerItem {
            let range = seekRange
            enrichNowPlaying(duration: range.upperBound-range.lowerBound,
                             position: currentItem.currentTime().seconds-range.lowerBound, rate: player.rate)
        } else {
            removeNowPlaying()
        }
        dumpState(reasonString)
    }

    func dumpState(_ reasonString: String = "undef") {
        logger.debug("dumpState: \(reasonString, privacy: .public)")
        logger.debug("playerStatus: \(self.playerStatus.debugDescription, privacy: .public)")
        logger.debug("playerItem: \(self.playerItem.debugDescription, privacy: .public)")

        guard let playerItem = playerItem else { return }
        let asset = playerItem.asset
        logger.debug("asset: \(asset.debugDescription, privacy: .public)")
        logger.debug("  duration: \(asset.duration.seconds)  overallDurationHint: \(asset.overallDurationHint.seconds)")
        logger.debug("  minimumTimeOffsetFromLive: \(asset.minimumTimeOffsetFromLive.seconds)")

        let currentTime = playerItem.currentTime()
        let currentDate = playerItem.currentDate()
        logger.debug("🟡 currentTime.seconds: \(currentTime.seconds) \(currentDate != nil ? currentDate!.localizedTimeString : "nil", privacy: .public)")

        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first,
           let loadedTimeRange = playerItem.loadedTimeRanges.map({ $0.timeRangeValue }).first {
            logger.debug("🟡 seekableTimeRange: start \(seekableTimeRange.start.seconds) end \(seekableTimeRange.end.seconds) duration \(seekableTimeRange.duration.seconds)")
            logger.debug("   loadedTimeRange:   start \(loadedTimeRange.start.seconds) end \(loadedTimeRange.end.seconds) duration \(loadedTimeRange.duration.seconds)")

            let earliestPosition = startTime.addingTimeInterval(seekableTimeRange.start.seconds
                                                                - seekableTimeRange.duration.seconds)
            logger.debug("   earliestPosition: \(earliestPosition.localizedTimeString, privacy: .public)")
            let newestPosition = startTime.addingTimeInterval(seekableTimeRange.end.seconds
                                                              - seekableTimeRange.duration.seconds)
            logger.debug("   newestPosition: \(newestPosition.localizedTimeString, privacy: .public)")
            let currentPosition = startTime.addingTimeInterval(currentTime.seconds - seekableTimeRange.duration.seconds)
            logger.debug("   currentPosition: \(currentPosition.localizedTimeString, privacy: .public)")

            logger.debug("   [\(seekableTimeRange.start.seconds) \(currentTime.seconds) \(seekableTimeRange.end.seconds)] \(currentTime.seconds > seekableTimeRange.end.seconds ? "🔴" : "", privacy: .public)")
            logger.debug("   [\(loadedTimeRange.start.seconds) \(currentTime.seconds) \(loadedTimeRange.end.seconds)] \(loadedTimeRange.end.seconds - currentTime.seconds)")
        }
    }

    func seek(to position: Double) {
        guard let playerItem = playerItem,
              let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first
        else {
            return
        }
        let newTime = CMTime(
            seconds: min(max(position, seekableTimeRange.start.seconds), seekableTimeRange.end.seconds),
            preferredTimescale: CMTimeScale(1)
        )
        logger.debug("🟣 Seek to \(position) => newTime = \(newTime.seconds)")
        playerItem.cancelPendingSeeks()
        playerItem.seek(to: newTime, completionHandler: { _ in
            self.logger.debug(" >>> 🟣 Seek finished: Now at \(playerItem.currentTime().seconds)")
            self.statusChanged("seek finished")
        })
    }

    func seek(toOffsetFromStart: Double) {
        seek(to: seekRange.lowerBound + toOffsetFromStart)
    }

    func seekToLive() {
        seek(to: seekRange.upperBound)
    }

    func stepBackward(_ count: Double = 15) {
        seek(to: currentPosition - count)
    }

    func stepForward(_ count: Double = 30) {
        seek(to: currentPosition + count)
    }

    var earliestSeekDate: Date {
        guard let playerItem = playerItem else { return .distantPast }
        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first {
            return startTime.addingTimeInterval(seekableTimeRange.start.seconds - seekableTimeRange.duration.seconds)
        }
        return startTime
    }

    var currentPosition: Double {
        get {
            playerItem?.currentTime().seconds ?? .infinity
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

    var duration: Double {
        seekRange.upperBound - seekRange.lowerBound
    }

    var isLive: Bool {
        currentPosition > (seekRange.upperBound - 15)
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
        if let seekableTimeRange = playerItem.seekableTimeRanges.map({ $0.timeRangeValue }).first {
            if seekableTimeRange.end.seconds > currentTime.seconds {
                return TimeInterval(currentTime.seconds - seekableTimeRange.end.seconds)
            }
        }
        return TimeInterval.zero
    }
}
