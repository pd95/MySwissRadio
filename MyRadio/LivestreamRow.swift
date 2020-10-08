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
            URLImage(url: stream.imageURL)
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
                .clipped()

            Text(stream.name)
                .padding(.horizontal)

            Spacer()

            if stream.isReady && !model.isLoading(stream: stream) {
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
                    .frame(width: 40, height: 40)
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
