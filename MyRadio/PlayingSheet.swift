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
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var seekRange = 0.0...1.0
    @State private var currentTime: Double = 100
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

            VStack {
                Slider(value: $currentTime, in: seekRange,
                       onEditingChanged: { c in
                            isDraggingSlider = c
                            print("\(c) => \(currentTime) \(model.controller.relativeSecondsToDate(currentTime).localizedTimeString)")
                            model.controller.currentTime = currentTime
                       },
                       label: { Text("Progress") }
                )
                .padding(0)

                HStack(alignment: .lastTextBaseline) {
                    Text(model.controller.earliestSeekDate, style: .time)

                    Text("\(currentDate.localizedTimeString)")
                        .onReceive(timer) { input in
                            self.currentDate = model.controller.currentDate
                            self.seekRange = model.controller.seekRange
                            if !isDraggingSlider {
                                self.currentTime = model.controller.currentTime
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .trailing) {
                        Text("Live")
                            .bold()
                        Text(model.controller.relativeOffsetToLive.relativeTimeString)
                    }
                }
                .padding(0)
            }
            .foregroundColor(.secondary)
            .accentColor(.secondary)
            .padding()

            HStack {
                Spacer()

                Button(action: { model.controller.stepBackward() }) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: { model.togglePlay(stream) }) {
                    Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: { model.controller.stepForward() }) {
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
        .onAppear() {
            self.currentDate = model.controller.currentDate
            self.seekRange = model.controller.seekRange
            self.currentTime = model.controller.currentTime
        }
    }
}

struct PlayingSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayingSheet(stream: .example)
            .environmentObject(MyRadioModel.main)
    }
}
