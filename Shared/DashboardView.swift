import Charts
import SwiftUI

enum PeriodKind: CaseIterable {
    case session, today, month

    var title: String {
        switch self {
        case .session: "Session"
        case .today: "Today"
        case .month: "Month"
        }
    }

    var color: Color {
        switch self {
        case .session: Theme.session
        case .today: Theme.today
        case .month: Theme.month
        }
    }

    func period(in summary: UsageSummary) -> UsagePeriod {
        switch self {
        case .session: summary.session
        case .today: summary.today
        case .month: summary.month
        }
    }
}

struct PeriodHeader: View {
    let kind: PeriodKind
    let detail: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(kind.color).frame(width: 7, height: 7)
            Text(kind.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
        }
    }
}

struct CostChart: View {
    let points: [UsagePoint]
    let color: Color

    private var maxCost: Double { max(points.map(\.cost).max() ?? 0, 0.01) }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(x: .value("Time", point.date), y: .value("Cost", point.cost))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", point.date), y: .value("Cost", point.cost))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(color)
            }
            if let last = points.last {
                PointMark(x: .value("Time", last.date), y: .value("Cost", last.cost))
                    .symbolSize(90)
                    .foregroundStyle(Theme.surface)
                PointMark(x: .value("Time", last.date), y: .value("Cost", last.cost))
                    .symbolSize(40)
                    .foregroundStyle(color)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...(maxCost * 1.12))
        .chartPlotStyle { plot in
            plot.overlay(alignment: .bottom) {
                Rectangle().fill(Theme.gridline).frame(height: 1)
            }
        }
    }
}

struct PeriodCard: View {
    enum Layout { case column, row }

    let kind: PeriodKind
    let period: UsagePeriod
    let layout: Layout

    var body: some View {
        switch layout {
        case .column:
            VStack(alignment: .leading, spacing: 4) {
                PeriodHeader(kind: kind, detail: "")
                value(size: 20)
                Text(Format.tokens(period.tokens))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
                CostChart(points: period.points, color: kind.color)
                    .padding(.top, 4)
            }
        case .row:
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    PeriodHeader(kind: kind, detail: period.detail)
                    value(size: 26)
                    Text(Format.tokens(period.tokens))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(width: 150, alignment: .leading)
                CostChart(points: period.points, color: kind.color)
            }
        }
    }

    private func value(size: CGFloat) -> some View {
        Text(Format.dollars(period.cost))
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .contentTransition(.numericText(value: period.cost))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

struct DashboardView: View {
    enum Size { case small, medium, large }

    let summary: UsageSummary
    let size: Size

    var body: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 4) {
                PeriodHeader(kind: .month, detail: "")
                Text(Format.dollars(summary.month.cost))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                CostChart(points: summary.month.points, color: Theme.month)
                HStack(spacing: 4) {
                    Circle().fill(Theme.today).frame(width: 6, height: 6)
                    Text("Today \(Format.dollars(summary.today.cost))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        case .medium:
            HStack(spacing: 14) {
                ForEach(PeriodKind.allCases, id: \.self) { kind in
                    PeriodCard(kind: kind, period: kind.period(in: summary), layout: .column)
                }
            }
        case .large:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(PeriodKind.allCases.enumerated()), id: \.element) { index, kind in
                    if index > 0 {
                        Rectangle().fill(Theme.gridline).frame(height: 1).padding(.vertical, 10)
                    }
                    PeriodCard(kind: kind, period: kind.period(in: summary), layout: .row)
                }
                Text("API-equivalent cost · updated \(summary.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 10)
            }
        }
    }
}

struct EmptyDashboardView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textMuted)
            Text("Open ClaudeCost to start tracking")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}
