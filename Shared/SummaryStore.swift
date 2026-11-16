import Foundation

struct SummaryStore {
    static let appGroup = "9KCYWB7246.com.kasperback.claudecost"

    let fileURL: URL

    static var shared: SummaryStore? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            .map { SummaryStore(fileURL: $0.appendingPathComponent("summary.json")) }
    }

    func load() -> UsageSummary? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? Self.decoder.decode(UsageSummary.self, from: data)
    }

    func save(_ summary: UsageSummary) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(summary).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}
