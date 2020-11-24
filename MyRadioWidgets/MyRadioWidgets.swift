//
//  MyRadioWidgets.swift
//  MyRadioWidgets
//
//  Created by Philipp on 09.10.20.
//

import WidgetKit
import SwiftUI
import Intents
import Combine

struct Provider: IntentTimelineProvider {

    static var streams = SettingsStore.shared.streams

    private func getStream(for station: Station?) -> Livestream? {
        guard let selectedStationID = station?.identifier ?? SettingsStore.shared.lastPlayedStreamId,
           let stream = Self.streams.first(where: { $0.id == selectedStationID })
        else  {
            return nil
        }

        return stream
    }

    private func isPlaying(stream: Livestream) -> Bool {
        SettingsStore.shared.lastPlayedStreamId == stream.id && SettingsStore.shared.isPlaying
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), livestream: .example, isPlaying: false)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let stream: Livestream = getStream(for: configuration.station) ?? .example
        let entry = SimpleEntry(date: Date(), livestream: stream, isPlaying: isPlaying(stream: stream))
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let stream: Livestream = getStream(for: configuration.station) ?? .example
        let entry = SimpleEntry(date: Date(), livestream: stream, isPlaying: isPlaying(stream: stream))
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let livestream: Livestream
    let isPlaying: Bool

    init(date: Date, livestream: Livestream, isPlaying: Bool) {
        self.date = date
        self.livestream = livestream
        self.isPlaying = isPlaying
    }
}

struct MyRadioWidgetsEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        MyRadioWidgetsView(
            image: entry.livestream.thumbnailImage ?? UIImage(named: "Placeholder")!,
            button: UIImage(systemName: entry.isPlaying ? "stop.circle" : "play.circle")!
        )
    }
}

@main
struct MyRadioWidgets: Widget {
    let kind: String = "MyRadioWidgets"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            MyRadioWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("My Swiss Radio")
        .description("Start playing your preferred radio station with a single tap.")
    }
}

struct MyRadioWidgets_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            MyRadioWidgetsEntryView(entry: SimpleEntry(date: Date(), livestream: .example, isPlaying: false))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            MyRadioWidgetsEntryView(entry: SimpleEntry(date: Date(), livestream: .example, isPlaying: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
