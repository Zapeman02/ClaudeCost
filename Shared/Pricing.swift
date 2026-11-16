import Foundation

struct ModelRate {
    let input: Double
    let output: Double
    let cacheRead: Double

    static let zero = ModelRate(input: 0, output: 0, cacheRead: 0)
}

enum Pricing {
    // USD per million tokens. Ordered most specific first because matching is by substring.
    private static let rates: [(key: String, rate: ModelRate)] = [
        ("fable-5-1", ModelRate(input: 10, output: 50, cacheRead: 0.25)),
        ("mythos-5-1", ModelRate(input: 10, output: 50, cacheRead: 0.25)),
        ("fable", ModelRate(input: 10, output: 50, cacheRead: 1.0)),
        ("mythos", ModelRate(input: 10, output: 50, cacheRead: 1.0)),
        ("opus-5-5", ModelRate(input: 4, output: 20, cacheRead: 0.20)),
        ("opus-5", ModelRate(input: 5, output: 25, cacheRead: 0.50)),
        ("opus-4-8", ModelRate(input: 5, output: 25, cacheRead: 0.50)),
        ("opus-4-7", ModelRate(input: 5, output: 25, cacheRead: 0.50)),
        ("opus-4-6", ModelRate(input: 5, output: 25, cacheRead: 0.50)),
        ("opus-4-5", ModelRate(input: 5, output: 25, cacheRead: 0.50)),
        ("opus", ModelRate(input: 15, output: 75, cacheRead: 1.50)),
        ("sonnet-5", ModelRate(input: 2, output: 10, cacheRead: 0.20)),
        ("sonnet", ModelRate(input: 3, output: 15, cacheRead: 0.30)),
        ("haiku-5-5", ModelRate(input: 0.10, output: 0.50, cacheRead: 0.01)),
        ("haiku-4-5", ModelRate(input: 1, output: 5, cacheRead: 0.10)),
        ("haiku", ModelRate(input: 0.80, output: 4, cacheRead: 0.08)),
    ]

    static func rate(for model: String) -> ModelRate {
        rates.first { model.contains($0.key) }?.rate ?? .zero
    }

    static func cost(model: String, usage: TokenUsage, fast: Bool) -> Double {
        let r = rate(for: model)
        let input: Double = Double(usage.input) * r.input
        let output: Double = Double(usage.output) * r.output
        let cacheRead: Double = Double(usage.cacheRead) * r.cacheRead
        let cacheWrite: Double = (Double(usage.cacheWrite5m) * 1.25 + Double(usage.cacheWrite1h) * 2) * r.input
        let multiplier: Double = fast ? 2 : 1
        return (input + output + cacheRead + cacheWrite) / 1_000_000 * multiplier
    }
}
