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

    private let startOfDayPlaceholder = Calendar.current.startOfDay(for: Date()).localizedTimeString

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
                    if model.isLive {
                        Text("Live")
                            .bold()
                    } else {
                        Button(action: model.seekToLive) {
                            Text("Live")
                                .bold()
                            Image(systemName: "forward.end.fill")
                        }
                    }
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Slider(value: $model.currentPosition, in: model.seekRange,
                       onEditingChanged: sliderModeChanged,
                       label: { Text("Progress") }
                )

                ZStack {
                    Text(model.earliestSeekDate, style: .time)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(startOfDayPlaceholder)
                        .opacity(0)
                        .overlay(Text("\(model.currentDate.localizedTimeString)"), alignment: .leading)

                    Text(model.relativeOffsetToLive.relativeTimeString)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .foregroundColor(.secondary)
            .accentColor(.secondary)
            .padding()

            HStack {
                Spacer()

                Button(action: model.stepBackward) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: model.togglePlayPause) {
                    Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: model.stepForward) {
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
        .disabled(model.playerIsInitialized == false)
        .onAppear {
            model.setupUITimer()
        }
        .onDisappear {
            model.removeUITimer()
        }
    }

    func sliderModeChanged(_ started: Bool) {
        isDraggingSlider = started
        if !started {
            model.seekToCurrentPosition()
        }
    }
}

struct PlayingSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayingSheet(stream: .example)
            .environmentObject(MyRadioModel.main)
    }
}
