//
//  LivestreamRow.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

struct LivestreamRow: View {

    let stream: Livestream

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if let uiImage = stream.thumbnailImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                } else {
                    ProgressView()
                }
            }
            .frame(height: 40)

            Text(stream.name)
                .padding(.horizontal)
        }
    }
}

struct LivestreamRow_Previews: PreviewProvider {
    @StateObject static private var model = MyRadioModel.example
    static var previews: some View {
        LivestreamRow(stream: Livestream.example)
            .environmentObject(model)
    }
}
