//
//  WhatsPlayingToolbar.swift
//  MyRadio
//
//  Created by Philipp on 14.10.20.
//

import SwiftUI

struct WhatsPlayingToolbar: View {

    @EnvironmentObject var model: MyRadioModel

    let stream: Livestream

    var body: some View {
        Group {
            HStack(spacing: 0) {
                if let uiImage = stream.thumbnailImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 48)
                        .clipped()
                }

                Text(stream.name)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: { model.togglePlay(stream) }) {
                Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                    .foregroundColor(!model.isPaused ? .red : .accentColor)
            }
            .border(Color.blue)
        }
    }
}
