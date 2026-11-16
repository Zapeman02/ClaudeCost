import Foundation

// Reads Claude Code's JSONL logs incrementally: each scan only parses bytes appended since the last one.
// Not thread-safe; UsageMonitor only calls it from its serial scan queue.
final class LogScanner: @unchecked Sendable {
    private let root: URL
    private var offsets: [URL: UInt64] = [:]
    private var entries: [String: UsageEntry] = [:]

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")) {
        self.root = root
    }

    func scan(since cutoff: Date) -> [UsageEntry] {
        for file in logFiles(modifiedAfter: cutoff) {
            read(file)
        }
        entries = entries.filter { $0.value.timestamp >= cutoff }
        return Array(entries.values)
    }

    private func logFiles(modifiedAfter cutoff: Date) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { url in
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { return false }
            return modified >= cutoff
        }
    }

    private func read(_ file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        var offset = offsets[file] ?? 0
        if size < offset { offset = 0 }
        guard size > offset else { return }

        try? handle.seek(toOffset: offset)
        guard let data = try? handle.read(upToCount: Int(size - offset)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n"))
        else { return }

        // Only consume complete lines; a partially written last line is picked up next scan.
        let complete = data[data.startIndex...lastNewline]
        for line in complete.split(separator: UInt8(ascii: "\n")) {
            if let entry = LogParser.parse(Data(line)) {
                entries[entry.id] = entry
            }
        }
        offsets[file] = offset + UInt64(complete.count)
    }
}
