import XCTest
@testable import UsageKit

final class PricingTests: XCTestCase {
    func testOpus55CostIncludesCacheTiers() {
        let usage = TokenUsage(input: 1_000_000, output: 1_000_000, cacheRead: 1_000_000, cacheWrite5m: 1_000_000, cacheWrite1h: 1_000_000)
        // 4 + 20 + 0.20 + 4*1.25 + 4*2
        XCTAssertEqual(Pricing.cost(model: "claude-opus-5-5", usage: usage, fast: false), 37.2, accuracy: 1e-9)
    }

    func testFastModeDoublesCost() {
        let usage = TokenUsage(output: 1_000_000)
        XCTAssertEqual(Pricing.cost(model: "claude-opus-5-5", usage: usage, fast: true), 40, accuracy: 1e-9)
    }

    func testSpecificModelWinsOverFamily() {
        XCTAssertEqual(Pricing.rate(for: "claude-sonnet-5-5").input, 2)
        XCTAssertEqual(Pricing.rate(for: "claude-sonnet-4-6").input, 3)
        XCTAssertEqual(Pricing.rate(for: "<synthetic>").input, 0)
    }
}

final class LogParserTests: XCTestCase {
    func testParsesAssistantUsageLine() throws {
        let line = """
        {"type":"assistant","timestamp":"2026-11-16T20:53:08.646Z","sessionId":"s1","requestId":"r1","cwd":"/Users/x/Desktop/Projects","message":{"id":"m1","model":"claude-opus-5-5","usage":{"input_tokens":2,"output_tokens":1000000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
        """
        let entry = try XCTUnwrap(LogParser.parse(Data(line.utf8)))
        XCTAssertEqual(entry.id, "m1|r1")
        XCTAssertEqual(entry.sessionId, "s1")
        XCTAssertEqual(entry.project, "Projects")
        XCTAssertEqual(entry.tokens, 1_000_002)
        XCTAssertEqual(entry.cost, 20.000008, accuracy: 1e-9)
    }

    func testIgnoresNonAssistantLines() {
        XCTAssertNil(LogParser.parse(Data(#"{"type":"user","message":{"content":"hi"}}"#.utf8)))
        XCTAssertNil(LogParser.parse(Data("not json".utf8)))
    }
}

final class SummaryBuilderTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func entry(_ id: String, _ session: String, _ at: Date, _ cost: Double) -> UsageEntry {
        UsageEntry(id: id, timestamp: at, sessionId: session, project: "Proj", tokens: 100, cost: cost)
    }

    func testTotalsPerPeriod() {
        let entries = [
            entry("a", "old", date(1, 10), 5),
            entry("b", "old", date(16, 9), 2),
            entry("c", "new", date(16, 11), 1),
            entry("d", "last-month", calendar.date(byAdding: .day, value: -1, to: date(1, 0))!, 99),
        ]
        let summary = SummaryBuilder(calendar: calendar).build(from: entries, now: date(16, 12))

        XCTAssertEqual(summary.month.cost, 8, accuracy: 1e-9)
        XCTAssertEqual(summary.today.cost, 3, accuracy: 1e-9)
        XCTAssertEqual(summary.session.cost, 1, accuracy: 1e-9)
        XCTAssertEqual(summary.session.detail, "Proj")
    }

    func testPointsAreCumulativeAndEndAtTotal() {
        let entries = [entry("a", "s", date(16, 1), 1), entry("b", "s", date(16, 5), 2)]
        let summary = SummaryBuilder(calendar: calendar).build(from: entries, now: date(16, 8))

        let costs = summary.today.points.map(\.cost)
        XCTAssertEqual(costs, costs.sorted())
        XCTAssertEqual(summary.today.points.last?.cost, 3)
        XCTAssertEqual(summary.month.points.last?.cost, 3)
        XCTAssertEqual(summary.session.points.last?.cost, 3)
    }
}

final class LogScannerTests: XCTestCase {
    func testReadsOnlyNewCompleteLines() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("s.jsonl")

        func line(_ id: String) -> String {
            #"{"type":"assistant","timestamp":"2026-11-16T10:00:00Z","sessionId":"s","requestId":"r","message":{"id":"\#(id)","model":"claude-opus-5-5","usage":{"output_tokens":10}}}"#
        }

        try (line("m1") + "\n" + line("m1") + "\n" + String(line("m2").prefix(40))).write(to: file, atomically: true, encoding: .utf8)
        let scanner = LogScanner(root: dir)
        XCTAssertEqual(scanner.scan(since: .distantPast).count, 1)

        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((String(line("m2").dropFirst(40)) + "\n").utf8))
        try handle.close()
        XCTAssertEqual(scanner.scan(since: .distantPast).count, 2)
    }
}
