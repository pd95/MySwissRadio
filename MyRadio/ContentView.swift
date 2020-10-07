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
                    Section(header: Text(bu.description)) {
                        if let streams = model.streams(for: bu), !streams.isEmpty {
                            ForEach(streams, id: \.self) { stream in
                                LivestreamRow(stream: stream)
                            }
                        }
                        else {
                            ProgressView()
                                .onAppear(perform: { model.refreshContent() })
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .environmentObject(model)
            .navigationTitle("My Swiss Radio")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: MyRadioModel.example)
    }
}
