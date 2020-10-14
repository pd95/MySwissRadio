//
//  ContentView.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: MyRadioModel

    var body: some View {
        NavigationView {
            List {
                ForEach(model.buSortOrder, id: \.self) { bu in
                    Section(header: Text(bu.description)) {
                        if let streams = model.streams(for: bu), !streams.isEmpty {
                            ForEach(streams) { stream in
                                Button(action: { play(stream: stream) }) {
                                    LivestreamRow(stream: stream)
                                }
                            }
                        }
                        else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .toolbar(content: {
                ToolbarItemGroup(placement: .bottomBar) {
                    model.currentlyPlaying.map { WhatsPlayingToolbar(stream: $0) }
                }
            })
            .navigationTitle("My Swiss Radio")
        }
    }

    func play(stream: Livestream) {
        if !model.isPlaying(stream: stream) {
            model.togglePlay(stream)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MyRadioModel.example)
    }
}
