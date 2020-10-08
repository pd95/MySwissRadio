//
//  URLImage.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import SwiftUI
import Combine

class URLImageViewModel: ObservableObject {

    let url: URL
    let networkClient: NetworkClient

    @Published var image: UIImage? = nil

    init(url: URL, networkClient: NetworkClient = .shared) {
        self.url = url
        self.networkClient = networkClient

        if let image = ImageCache.shared[url] {
            self.image = image
        }
    }

    func fetchImage() {
        let url = self.url
        SRGService.getImageResource(client: networkClient, for: url)
            .map( { image in
                if let image = image {
                    ImageCache.shared[url] = image
                    print(image.size)
                }
                return image
            })
            .receive(on: DispatchQueue.main)
            .assign(to: &$image)
    }
}

struct URLImage: View {
    @ObservedObject var model: URLImageViewModel

    init(_ model: URLImageViewModel) {
        self.model = model
    }

    var body: some View {
        Group {
            if let uiImage = self.model.image {
                Image(uiImage: uiImage)
                    .resizable()
            }
            else {
                ProgressView()
                    .onAppear() {
                        self.model.fetchImage()
                    }
            }
        }
    }
}


struct URLImage_Previews: PreviewProvider {
    static var previews: some View {
        URLImage(URLImageViewModel(url: Livestream.example.imageURL))
            .aspectRatio(contentMode: .fit)
            //.border(Color.black, width: 3)
    }
}
