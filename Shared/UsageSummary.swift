import Foundation

struct UsagePoint: Codable, Equatable, Identifiable {
    let date: Date
    let cost: Double

    var id: Date { date }
}

struct UsagePeriod: Codable, Equatable {
    let cost: Double
    let tokens: Int
    let detail: String
    let points: [UsagePoint]

    static let empty = UsagePeriod(cost: 0, tokens: 0, detail: "", points: [])
}

struct UsageSummary: Codable, Equatable {
    let generatedAt: Date
    let session: UsagePeriod
    let today: UsagePeriod
    let month: UsagePeriod
    var limits: PlanLimits?
}

struct LimitWindow: Codable, Equatable {
    let usedPercent: Double
    let resetsAt: Date

    // Claude Code stops reporting a window once it resets, so a passed reset means the window is fresh.
    func percent(at now: Date) -> Double {
        now >= resetsAt ? 0 : usedPercent
    }
}

// Plan rate limits saved by scripts/statusline.sh from Claude Code's status line data.
struct PlanLimits: Codable, Equatable {
    let session: LimitWindow?
    let week: LimitWindow?

    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claudecost-limits.json")

    static func load(from url: URL = defaultURL) -> PlanLimits? {
        (try? Data(contentsOf: url)).flatMap(parse)
    }

    static func parse(_ data: Data) -> PlanLimits? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let limits = PlanLimits(session: window(json["five_hour"]), week: window(json["seven_day"]))
        return limits.session == nil && limits.week == nil ? nil : limits
    }

    private static func window(_ value: Any?) -> LimitWindow? {
        guard let dict = value as? [String: Any],
              let used = (dict["used_percentage"] as? NSNumber)?.doubleValue,
              let resets = (dict["resets_at"] as? NSNumber)?.doubleValue else { return nil }
        return LimitWindow(usedPercent: used, resetsAt: Date(timeIntervalSince1970: resets))
    }
}

struct SummaryBuilder {
    var calendar = Calendar.current
    var sessionBuckets = 40

    func build(from entries: [UsageEntry], now: Date) -> UsageSummary {
        let dayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? dayStart
        let monthEntries = entries.filter { $0.timestamp >= monthStart && $0.timestamp <= now }
        let todayEntries = monthEntries.filter { $0.timestamp >= dayStart }

        return UsageSummary(
            generatedAt: now,
            session: session(from: entries),
            today: period(todayEntries, from: dayStart, to: now, step: .hour, detail: Self.dayFormatter.string(from: now)),
            month: period(monthEntries, from: monthStart, to: now, step: .day, detail: Self.monthFormatter.string(from: now))
        )
    }

    private func session(from entries: [UsageEntry]) -> UsagePeriod {
        guard let latest = entries.max(by: { $0.timestamp < $1.timestamp }) else { return .empty }
        let sessionEntries = entries.filter { $0.sessionId == latest.sessionId }
        let start = sessionEntries.map(\.timestamp).min() ?? latest.timestamp
        let span = max(latest.timestamp.timeIntervalSince(start), 1)
        let width = span / Double(sessionBuckets)
        let boundaries = (0...sessionBuckets).map { start.addingTimeInterval(Double($0) * width) }
        return UsagePeriod(
            cost: sessionEntries.reduce(0) { $0 + $1.cost },
            tokens: sessionEntries.reduce(0) { $0 + $1.tokens },
            detail: latest.project,
            points: cumulative(sessionEntries, at: boundaries)
        )
    }

    private func period(_ entries: [UsageEntry], from start: Date, to end: Date, step: Calendar.Component, detail: String) -> UsagePeriod {
        var boundaries: [Date] = []
        var cursor = start
        while cursor < end {
            boundaries.append(cursor)
            guard let next = calendar.date(byAdding: step, value: 1, to: cursor) else { break }
            cursor = next
        }
        boundaries.append(end)
        return UsagePeriod(
            cost: entries.reduce(0) { $0 + $1.cost },
            tokens: entries.reduce(0) { $0 + $1.tokens },
            detail: detail,
            points: cumulative(entries, at: boundaries)
        )
    }

    // Running total of cost up to and including each boundary.
    private func cumulative(_ entries: [UsageEntry], at boundaries: [Date]) -> [UsagePoint] {
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        var index = 0
        var total = 0.0
        return boundaries.map { boundary in
            while index < sorted.count, sorted[index].timestamp <= boundary {
                total += sorted[index].cost
                index += 1
            }
            return UsagePoint(date: boundary, cost: total)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()
}
