import WidgetKit
import SwiftUI

// MARK: - Shared Constants

private let appGroupId = "group.com.bigmints.fikr"
private let deepLinkURL = URL(string: "fikr://record")!

// MARK: - Timeline Entry

struct FikrWidgetEntry: TimelineEntry {
    let date: Date
    let lastNoteTitle: String?
}

// MARK: - Timeline Provider

struct FikrWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FikrWidgetEntry {
        FikrWidgetEntry(date: .now, lastNoteTitle: "My latest thought")
    }

    func getSnapshot(in context: Context, completion: @escaping (FikrWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FikrWidgetEntry>) -> Void) {
        let timeline = Timeline(entries: [entry()], policy: .never)
        completion(timeline)
    }

    private func entry() -> FikrWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let title = defaults?.string(forKey: "lastNoteTitle")
        return FikrWidgetEntry(date: .now, lastNoteTitle: title)
    }
}

// MARK: - Widget View

struct FikrWidgetEntryView: View {
    var entry: FikrWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0F0F1A"), Color(hex: "#1A1A2E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: family == .systemSmall ? 26 : 32, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.6), radius: 8)

                Text("Fikr")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let title = entry.lastNoteTitle, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                } else {
                    Text("Tap to record a thought")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(12)
        }
        .widgetURL(deepLinkURL)
    }
}

// MARK: - Widget Configuration

struct FikrRecordWidget: Widget {
    static let kind = "FikrRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FikrWidgetProvider()) { entry in
            FikrWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Fikr – Record")
        .description("Tap to record a voice note instantly.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct FikrWidgetBundle: WidgetBundle {
    var body: some Widget {
        FikrRecordWidget()
    }
}

// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
