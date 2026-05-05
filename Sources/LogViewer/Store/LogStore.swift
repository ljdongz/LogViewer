import Foundation
import Combine

@MainActor
public final class LogStore: ObservableObject {

    public static let shared = LogStore()

    @Published public private(set) var entries: [LogEntry] = []
    var maxCount: Int = 500

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private init() {}

    // MARK: - Write

    /// Non-isolated convenience so callers on any thread can log without `await`.
    nonisolated public func log(
        level: LogEntry.Level = .log,
        category: String = "Default",
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line
        )
        Task { @MainActor in
            guard LogViewer.isEnabled else { return }
            self.append(entry)
        }
    }

    public func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxCount {
            entries.removeFirst(entries.count - maxCount)
        }
    }

    // MARK: - Clear

    public func clear() {
        entries.removeAll()
    }

    // MARK: - Export

    public func exportAsText(includeLocation: Bool = true) -> String {
        entries.map { $0.formatted(includeLocation: includeLocation) }.joined(separator: "\n")
    }

    public func exportAsLogFile(includeLocation: Bool = true) -> URL {
        let text = exportAsText(includeLocation: includeLocation)
        let timestamp = Self.fileNameFormatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logs_\(timestamp).log")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Query

    public var availableCategories: [String] {
        Array(Set(entries.map(\.category))).sorted()
    }
}
