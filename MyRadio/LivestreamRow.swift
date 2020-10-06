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
        HStack {
            Image(systemName: "photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 40)
            Text(stream.name)
                .padding()
            Spacer()
            Group {
                if stream.isReady {
                    Button(action: { model.togglePlay(stream) }) {
                        Image(systemName: model.isPlaying(stream: stream) ? "stop.circle" : "play.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                else {
                    ProgressView()
                }
            }
            .frame(maxHeight: 40)
        }
    }
}

struct LivestreamRow_Previews: PreviewProvider {
    @StateObject static private var model = MyRadioModel()
    static var previews: some View {
        LivestreamRow(stream: model.streams.first!)
            .environmentObject(model)
    }
}
