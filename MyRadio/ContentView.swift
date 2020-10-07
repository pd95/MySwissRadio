//
//  ContentView.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import SwiftUI

struct ContentView: View {
    let model: MyRadioModel

    var body: some View {
        NavigationView {
            List {
                ForEach(model.buSortOrder, id: \.self) { bu in
                    if let streams = model.streams(for: bu) {
                    Section(header: Text(bu.description)) {
                            ForEach(streams, id: \.self) { stream in
                                LivestreamRow(stream: stream)
                            }
                        }
                    }
                }
            }
            .environmentObject(model)
            .navigationTitle("My Swiss Radio")
            .onAppear(perform: { model.refreshContent() })
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: MyRadioModel.example)
    }
}
