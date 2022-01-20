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
                        if let streams = model.streamStore.streams(for: bu), !streams.isEmpty {
                            ForEach(streams) { stream in
                                Button(action: { play(stream: stream) }) {
                                    LivestreamRow(stream: stream)
                                }
                            }
                        } else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .sheet(isPresented: $model.showSheet, content: {
                model.currentlyPlaying.map {
                    PlayingSheet(stream: $0)
                        .environmentObject(model)
                }
            })
            .toolbar(content: {
                ToolbarItemGroup(placement: .bottomBar) {
                    model.currentlyPlaying.map {
                        WhatsPlayingToolbar(stream: $0)
                            .onTapGesture {
                                model.showSheet = true
                            }
                    }
                }
            })
            .navigationTitle("My Swiss Radio")
        }
        .navigationViewStyle(.stack)
    }

    func play(stream: Livestream) {
        if !model.isPlaying(stream: stream) {
            model.togglePlay(stream)
        } else {
            model.showSheet = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MyRadioModel.example)
    }
}
