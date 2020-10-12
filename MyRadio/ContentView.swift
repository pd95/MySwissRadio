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
                            ForEach(streams, id: \.self) { stream in
                                LivestreamRow(stream: stream)
                            }
                        }
                        else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .onAppear(perform: {
                if model.streams.isEmpty {
                    model.refreshContent()
                }
            })
            .navigationTitle("My Swiss Radio")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MyRadioModel.example)
    }
}
