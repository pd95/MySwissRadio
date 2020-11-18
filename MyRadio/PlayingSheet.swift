//
//  PlayingSheet.swift
//  MyRadio
//
//  Created by Philipp on 14.10.20.
//

import SwiftUI

struct PlayingSheet: View {

    @EnvironmentObject var model: MyRadioModel

    let stream: Livestream

    @State private var seekRange = 0.0...1.0
    @State private var currentPosition: Double = .infinity
    @State private var currentDate: Date = Date()
    @State private var isDraggingSlider = false

    var body: some View {
        VStack {
            Capsule()
                .frame(width: 40, height: 5)
                .foregroundColor(.secondary)
                .padding(.top)

            Text(stream.name)
                .font(.largeTitle)

            Image(uiImage: stream.thumbnailImage ?? UIImage(systemName: "photo")!)
                .resizable()
                .scaledToFit()

            VStack(spacing: 0) {
                HStack {
                    if model.controller.isLive {
                        Text("Live")
                            .bold()
                    }
                    else {
                        Button(action: model.controller.seekToLive) {
                            Text("Live")
                                .bold()
                            Image(systemName: "forward.end.fill")
                        }
                    }
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Slider(value: $currentPosition, in: seekRange,
                       onEditingChanged: sliderModeChanged,
                       label: { Text("Progress") }
                )

                ZStack {
                    Text(model.controller.earliestSeekDate, style: .time)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("00:00:00")
                        .opacity(0.0)
                        .overlay(Text("\(currentDate.localizedTimeString)"), alignment: .leading)

                    Text(model.controller.relativeOffsetToLive.relativeTimeString)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .onReceive(model.uiUpdateTimer, perform: updateState)
            }
            .foregroundColor(.secondary)
            .accentColor(.secondary)
            .padding()

            HStack {
                Spacer()

                Button(action: stepBackward) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: togglePlayPause) {
                    Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: stepForward) {
                    Image(systemName: "goforward.30")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()
            }
            .padding()

            Spacer()
        }
        .disabled(model.controller.playerStatus == .undefined)
    }

    func updateState(_ time: Date = Date()) {
        guard model.controller.playerStatus != .undefined && !isDraggingSlider else {
            return
        }

        currentDate = model.controller.currentDate
        seekRange = model.controller.seekRange
        currentPosition = model.controller.currentPosition
    }

    func togglePlayPause() {
        model.togglePlay(stream)
        updateState()
    }

    func stepBackward() {
        model.controller.stepBackward()
        updateState()
    }

    func stepForward() {
        model.controller.stepForward()
        updateState()
    }

    func sliderModeChanged(_ started: Bool) {
        isDraggingSlider = started
        print("\(started) => \(currentPosition) \(model.controller.relativeSecondsToDate(currentPosition).localizedTimeString)")
        if !started {
            model.controller.currentPosition = currentPosition
        }
    }
}

struct PlayingSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayingSheet(stream: .example)
            .environmentObject(MyRadioModel.main)
    }
}
