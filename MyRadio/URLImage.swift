//
//  URLImage.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import SwiftUI

struct URLImage: View {
    let url: URL

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage = self.uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            }
            else {
                ProgressView()
                    .onReceive(
                        NetworkClient.shared.getImageResource(for: url)
                            .receive(on: DispatchQueue.main),
                        perform: { uiImage = $0 }
                    )
            }
        }
    }
}


struct URLImage_Previews: PreviewProvider {
    static var previews: some View {
        URLImage(url: Livestream.example.imageURL)
            .aspectRatio(contentMode: .fit)
            //.border(Color.black, width: 3)
    }
}
