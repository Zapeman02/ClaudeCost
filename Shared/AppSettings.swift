import Foundation

// Stored in the App Group so the widget can read the refresh interval too.
enum AppSettings {
    static let defaults = UserDefaults(suiteName: SummaryStore.appGroup) ?? .standard

    static let refreshKey = "widgetRefreshMinutes"
    static let loginItemConfiguredKey = "loginItemConfigured"
    static let refreshOptions = [1, 5, 15, 30, 60]
    static let defaultRefreshMinutes = 5

    static let menuBarItemKey = "menuBarItem"
    static let menuBarLayoutKey = "menuBarLayout"

    static let sessionFolderKey = "sessionFolder"
    static let defaultSessionFolder = NSHomeDirectory() + "/Desktop/Projects"

    static var sessionFolder: String {
        defaults.string(forKey: sessionFolderKey) ?? defaultSessionFolder
    }

    static var widgetRefreshInterval: TimeInterval {
        let minutes = defaults.integer(forKey: refreshKey)
        return Double(minutes > 0 ? minutes : defaultRefreshMinutes) * 60
    }
}

enum MenuBarLayout: String, CaseIterable {
    case inline, stacked

    var title: String {
        switch self {
        case .inline: "Inline"
        case .stacked: "Stacked"
        }
    }
}

enum MenuBarItem: String, CaseIterable {
    case session, today, month, fiveHour, week, closestLimit

    var title: String {
        switch self {
        case .session: "Session cost"
        case .today: "Today's cost"
        case .month: "Month's cost"
        case .fiveHour: "5-hour limit"
        case .week: "Weekly limit"
        case .closestLimit: "Closest limit (auto)"
        }
    }

    func text(for summary: UsageSummary?) -> String {
        switch self {
        case .session: return Format.dollars(summary?.session.cost ?? 0)
        case .today: return Format.dollars(summary?.today.cost ?? 0)
        case .month: return Format.dollars(summary?.month.cost ?? 0)
        case .fiveHour, .week, .closestLimit: return limitKind(for: summary)?.title ?? LimitKind.week.title
        }
    }

    /// Used share of the plan limit (0...1), or nil for cost items and missing limit data.
    func progress(for summary: UsageSummary?) -> Double? {
        limitKind(for: summary)?.window(in: summary?.limits).map { min($0.percent(at: .now), 100) / 100 }
    }

    private func limitKind(for summary: UsageSummary?) -> LimitKind? {
        switch self {
        case .session, .today, .month: return nil
        case .fiveHour: return .fiveHour
        case .week: return .week
        case .closestLimit: return LimitChoice.closest.kinds(in: summary?.limits).first
        }
    }
}
