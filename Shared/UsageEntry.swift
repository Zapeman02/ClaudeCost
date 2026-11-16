import Foundation

struct TokenUsage: Equatable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite5m = 0
    var cacheWrite1h = 0

    var total: Int { input + output + cacheRead + cacheWrite5m + cacheWrite1h }
}

struct UsageEntry: Equatable {
    let id: String
    let timestamp: Date
    let sessionId: String
    let project: String
    let tokens: Int
    let cost: Double
}

enum LogParser {
    private struct Line: Decodable {
        let type: String
        let timestamp: String?
        let sessionId: String?
        let requestId: String?
        let cwd: String?
        let message: Message?
    }

    private struct Message: Decodable {
        let id: String?
        let model: String?
        let usage: Usage?
    }

    private struct Usage: Decodable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_read_input_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_creation: CacheCreation?
        let speed: String?
    }

    private struct CacheCreation: Decodable {
        let ephemeral_5m_input_tokens: Int?
        let ephemeral_1h_input_tokens: Int?
    }

    private static let assistantMarker = Data("\"type\":\"assistant\"".utf8)
    private static let decoder = JSONDecoder()

    static func parse(_ line: Data) -> UsageEntry? {
        guard line.range(of: assistantMarker) != nil,
              let raw = try? decoder.decode(Line.self, from: line),
              raw.type == "assistant",
              let message = raw.message, let usage = message.usage,
              let model = message.model,
              let ts = raw.timestamp, let date = parseDate(ts),
              let sessionId = raw.sessionId
        else { return nil }

        var tokens = TokenUsage(
            input: usage.input_tokens ?? 0,
            output: usage.output_tokens ?? 0,
            cacheRead: usage.cache_read_input_tokens ?? 0
        )
        if let split = usage.cache_creation {
            tokens.cacheWrite5m = split.ephemeral_5m_input_tokens ?? 0
            tokens.cacheWrite1h = split.ephemeral_1h_input_tokens ?? 0
        } else {
            tokens.cacheWrite5m = usage.cache_creation_input_tokens ?? 0
        }

        return UsageEntry(
            id: "\(message.id ?? ts)|\(raw.requestId ?? "")",
            timestamp: date,
            sessionId: sessionId,
            project: raw.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "",
            tokens: tokens.total,
            cost: Pricing.cost(model: model, usage: tokens, fast: usage.speed == "fast")
        )
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plainFormatter = ISO8601DateFormatter()

    private static func parseDate(_ string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? plainFormatter.date(from: string)
    }
}
