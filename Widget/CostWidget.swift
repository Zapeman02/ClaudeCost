import AppIntents
import SwiftUI
import WidgetKit

enum PeriodOption: String, AppEnum {
    case session, today, month

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static let caseDisplayRepresentations: [PeriodOption: DisplayRepresentation] = [
        .session: "Session",
        .today: "Today",
        .month: "Month",
    ]

    var kind: PeriodKind {
        switch self {
        case .session: .session
        case .today: .today
        case .month: .month
        }
    }
}

struct CostWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Claude Cost"
    static let description = IntentDescription("Choose which period the small widget shows.")

    @Parameter(title: "Period", default: .month)
    var period: PeriodOption
}

struct CostEntry: TimelineEntry {
    let date: Date
    let summary: UsageSummary?
    let period: PeriodKind
}

struct CostProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CostEntry {
        CostEntry(date: .now, summary: nil, period: .month)
    }

    func snapshot(for configuration: CostWidgetIntent, in context: Context) async -> CostEntry {
        CostEntry(date: .now, summary: SummaryStore.shared?.load(), period: configuration.period.kind)
    }

    func timeline(for configuration: CostWidgetIntent, in context: Context) async -> Timeline<CostEntry> {
        let entry = CostEntry(date: .now, summary: SummaryStore.shared?.load(), period: configuration.period.kind)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(AppSettings.widgetRefreshInterval)))
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
        case .systemSmall: .small(entry.period)
        case .systemMedium: .medium
        default: .large
        }
    }
}

@main
struct CostWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "CostWidget", intent: CostWidgetIntent.self, provider: CostProvider()) { entry in
            CostWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Cost")
        .description("API-equivalent cost of your Claude Code usage. Click to start a new session.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
