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
    static let networkClient = NetworkClient()

    static let streams = SettingsStore.shared.streams

    static var cancellables = Set<AnyCancellable>()

    private func fetchImage(_ stream: Livestream) {
        Self.networkClient.dataRequest(for: stream.thumbnailImageURL)
            .map({ UIImage(data: $0) })
            .replaceError(with: nil)
            .sink { (image) in
                if let image = image  {
                    try? stream.saveThumbnail(image)
                }
            }
            .store(in: &Self.cancellables)
    }

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

    var stretchableImage: UIImage {
        entry.livestream.thumbnailImage ?? UIImage(named: "SRF3")!
    }

    var iconName: String {
        entry.isPlaying ? "stop.circle" : "play.circle"
    }

    var iconColor: Color {
        entry.isPlaying ? Color.primary.opacity(0.6) : .primary
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Image(uiImage: stretchableImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(iconColor)
                    .shadow(color: Color(.systemBackground), radius: 10, x: 0, y: 0)
                    .frame(maxHeight: 40)
            }
        }
        .background(
            Image(uiImage: stretchableImage)
                .resizable()
                .scaleEffect(400, anchor: .bottomLeading)
                .offset(x: -40, y: +80)
                .blur(radius: 10)
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
