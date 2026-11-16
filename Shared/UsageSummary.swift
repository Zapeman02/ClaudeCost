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
