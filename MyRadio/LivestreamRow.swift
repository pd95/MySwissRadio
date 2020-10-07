//
//  LivestreamRow.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

struct LivestreamRow: View {

    @EnvironmentObject var model: MyRadioModel

    let stream: Livestream

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
            Text(stream.name)
                .padding(.horizontal)

            Spacer()

            if stream.isReady {
                Button(action: { model.togglePlay(stream) }) {
                    Image(systemName: model.isPlaying(stream: stream) ? "stop.circle" : "play.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(model.isPlaying(stream: stream) ? .red : .accentColor)
                }
                .frame(maxHeight: 40)
                .buttonStyle(BorderlessButtonStyle())
            }
            else {
                ProgressView()
            }
        }
    }
}

struct LivestreamRow_Previews: PreviewProvider {
    @StateObject static private var model = MyRadioModel.example
    static var previews: some View {
        LivestreamRow(stream: model.streams.first!)
            .environmentObject(model)
    }
}
