//
//  MyRadioWidgetsView.swift
//  MyRadio
//
//  Created by Philipp on 23.11.20.
//

import SwiftUI
import WidgetKit

struct MyRadioWidgetsView: View {

    let image: UIImage
    let button: UIImage

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                // FB8915721: The image is not visible in Xcode preview/simulator
                // clipShape seems to be the reason
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(ContainerRelativeShape())
                    .shadow(radius: 5)

                Image(uiImage: button)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.primary)
                    .shadow(color: Color(.gray), radius: 5, x: 0, y: 0)
                    .shadow(color: Color(.white), radius: 5, x: 0, y: 0)
                    .frame(maxHeight: 40)
            }
            .padding(8)
        }
        .background(
            Image(uiImage: image)
                .blur(radius: image.size.width/10)
        )
    }
}

struct MyRadioWidgetsView_Previews: PreviewProvider {
    static var images: [UIImage] = [
        UIImage(named: "Placeholder")!,
//        UIImage(named: "SRF1")!, UIImage(named: "SRF2")!, UIImage(named: "SRF3")!,
//        UIImage(named: "SRFInfo")!, UIImage(named: "SRFVirus")!, UIImage(named: "SRFMusikwelle")!,
//        UIImage(named: "RTS1")!, UIImage(named: "RTS2")!, UIImage(named: "RTS3")!, UIImage(named: "RTS4")!,
//        UIImage(named: "RSI1")!, UIImage(named: "RSI2")!, UIImage(named: "RSI3")!,
//        UIImage(named: "RTR")!
    ]

    static var previews: some View {
        Group {
            ForEach(images, id: \.self) { image in
                MyRadioWidgetsView(image: image, button: UIImage(systemName: "play.circle")!)
                    .previewContext(WidgetPreviewContext(family: .systemSmall))
            }
        }.environment(\.colorScheme, .dark)
    }
}
