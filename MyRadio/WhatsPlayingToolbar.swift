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

            Button {
                model.togglePlay(stream)
            } label: {
                Image(systemName: !model.isPaused ? "pause.fill" : "play.fill")
                    .foregroundColor(!model.isPaused ? .red : .accentColor)
            }
        }
    }
}

struct WhatsPlayingToolbar_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            Text("")
                .toolbar(content: {
                    ToolbarItemGroup(placement: .bottomBar) {
                        WhatsPlayingToolbar(stream: .example)
                    }
                })
        }
        .environmentObject(MyRadioModel.main)
    }
}
