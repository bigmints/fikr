import WidgetKit
import SwiftUI

private let appGroupId = "group.com.bigmints.fikr"
private let deepLinkURL = URL(string: "fikr://record")!

struct FikrWidgetEntry: TimelineEntry {
    let date: Date
    let lastNoteTitle: String?
}

struct FikrWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FikrWidgetEntry {
        FikrWidgetEntry(date: .now, lastNoteTitle: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FikrWidgetEntry) -> Void) {
        completion(FikrWidgetEntry(date: .now, lastNoteTitle: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FikrWidgetEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "lastNoteTitle")
        let entry = FikrWidgetEntry(date: .now, lastNoteTitle: title)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct FikrWidgetEntryView: View {
    var entry: FikrWidgetEntry

    var body: some View {
        VStack(spacing: 14) {
            Image("FikrLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 5) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 13, weight: .medium))
                Text("Record")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(deepLinkURL)
    }
}

struct FikrRecordWidget: Widget {
    static let kind = "FikrRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FikrWidgetProvider()) { entry in
            FikrWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fikr")
        .description("Tap to record a voice note.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FikrWidgetBundle: WidgetBundle {
    var body: some Widget {
        FikrRecordWidget()
    }
}
