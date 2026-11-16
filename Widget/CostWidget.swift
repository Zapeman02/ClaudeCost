import SwiftUI
import WidgetKit

struct CostEntry: TimelineEntry {
    let date: Date
    let summary: UsageSummary?
}

struct CostProvider: TimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        CostEntry(date: .now, summary: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CostEntry) -> Void) {
        completion(CostEntry(date: .now, summary: SummaryStore.shared?.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CostEntry>) -> Void) {
        let entry = CostEntry(date: .now, summary: SummaryStore.shared?.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(AppSettings.widgetRefreshInterval))))
    }
}

struct CostWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CostEntry

    var body: some View {
        Group {
            if let summary = entry.summary {
                DashboardView(summary: summary, size: size)
            } else {
                EmptyDashboardView()
            }
        }
        .containerBackground(Theme.surface, for: .widget)
        .widgetURL(URL(string: "claudecost://new-session"))
    }

    private var size: DashboardView.Size {
        switch family {
        case .systemSmall: .small
        case .systemMedium: .medium
        default: .large
        }
    }
}

@main
struct CostWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CostWidget", provider: CostProvider()) { entry in
            CostWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Cost")
        .description("API-equivalent cost of your Claude Code usage. Click to start a new session.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
