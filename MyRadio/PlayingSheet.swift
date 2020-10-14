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

    @State private var position: CGFloat = 100

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
                Slider(value: $position, in: 0.0...100.0,
                       onEditingChanged: { c in print("\(c) => \(position)") },
                       label: { Text("Progress") }
                )
                .padding(0)

                HStack {
                    Text("12:00:00")
                    Spacer()
                    Text("Live")
                }
                .padding(0)
            }
            .foregroundColor(.secondary)
            .accentColor(.secondary)
            .padding()

            HStack {
                Spacer()

                Button(action: {  }) {
                    Image(systemName: "gobackward.15")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }
                .disabled(true)

                Spacer()

                Button(action: { model.togglePlay(stream) }) {
                    Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }

                Spacer()

                Button(action: {  }) {
                    Image(systemName: "goforward.30")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 40, maxHeight: 40)
                }
                .disabled(true)

                Spacer()
            }
            .padding()

            Spacer()
        }
    }
}

struct PlayingSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlayingSheet(stream: .example)
            .environmentObject(MyRadioModel.main)
    }
}
