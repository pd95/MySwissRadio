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

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationIntent(), livestream: .example, isPlaying: false)
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), configuration: configuration, livestream: .example, isPlaying: false)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for streamOffset in 0 ..< Self.streams.count {
            let entryDate = Calendar.current.date(byAdding: .second, value: 5*streamOffset, to: currentDate)!
            let stream = Self.streams[streamOffset]
            let entry = SimpleEntry(date: entryDate, configuration: configuration, livestream: stream, isPlaying: false)
            entries.append(entry)

            if stream.thumbnailImage == nil {
                fetchImage(stream)
            }
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    let livestream: Livestream
    let isPlaying: Bool
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
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct MyRadioWidgets_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MyRadioWidgetsEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), livestream: .example, isPlaying: false))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            MyRadioWidgetsEntryView(entry: SimpleEntry(date: Date(), configuration: ConfigurationIntent(), livestream: .example, isPlaying: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
