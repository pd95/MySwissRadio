//
//  ContentView.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

struct ContentView: View {
    @State private var channels: [Channel] = []

    var body: some View {
        NavigationView {
            List {
                ForEach(channels) { channel in
                    HStack {
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 40)
                        Text(channel.name)
                            .padding()
                        Spacer()
                    }
                }
            }
            .navigationTitle("My Radio")
            .onReceive(NetworkClient.shared.getChannels(), perform: { data in
                print("received: \(data)")
                self.channels = data
            })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
