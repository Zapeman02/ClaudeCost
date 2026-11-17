import Foundation
import WidgetKit

@MainActor
final class UsageMonitor: ObservableObject {
    @Published private(set) var summary: UsageSummary?

    private let scanner = LogScanner()
    private let builder = SummaryBuilder()
    private let store = SummaryStore.shared
    private let queue = DispatchQueue(label: "claudecost.scan", qos: .utility)
    private var timer: Timer?
    private var lastWidgetReload = Date.distantPast

    init() {
        summary = store?.load()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        let scanner = scanner
        let builder = builder
        queue.async {
            let now = Date()
            let monthStart = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
            var summary = builder.build(from: scanner.scan(since: monthStart), now: now)
            summary.limits = PlanLimits.load()
            Task { @MainActor in self.publish(summary) }
        }
    }

    private func publish(_ new: UsageSummary) {
        let changed = !Self.sameCosts(summary, new)
        summary = new
        try? store?.save(new)
        // WidgetKit budgets reloads, so only ask when the numbers actually moved.
        if changed, Date().timeIntervalSince(lastWidgetReload) >= AppSettings.widgetRefreshInterval {
            lastWidgetReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func sameCosts(_ a: UsageSummary?, _ b: UsageSummary) -> Bool {
        guard let a else { return false }
        return Int(a.session.cost * 100) == Int(b.session.cost * 100)
            && Int(a.today.cost * 100) == Int(b.today.cost * 100)
            && Int(a.month.cost * 100) == Int(b.month.cost * 100)
            && a.limits?.session.map { Int($0.usedPercent) } == b.limits?.session.map { Int($0.usedPercent) }
            && a.limits?.week.map { Int($0.usedPercent) } == b.limits?.week.map { Int($0.usedPercent) }
    }
}
