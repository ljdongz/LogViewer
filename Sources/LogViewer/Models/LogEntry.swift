import Foundation

public struct LogEntry: Identifiable, Equatable, Sendable {

    public enum Level: String, CaseIterable, Equatable, Comparable, Sendable {
        case log = "LOG"
        case notice = "NOTICE"
        case warning = "WARN"
        case error = "ERROR"
        case critical = "CRITICAL"
        case fault = "FAULT"

        var severity: Int {
            switch self {
            case .log: return 0
            case .notice: return 1
            case .warning: return 2
            case .error: return 3
            case .critical: return 4
            case .fault: return 5
            }
        }

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.severity < rhs.severity
        }
    }

    public let id: UUID
    public let timestamp: Date
    public let level: Level
    public let category: String
    public let message: String
    public let file: String
    public let function: String
    public let line: Int

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: Level,
        category: String,
        message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }

    public var fileName: String {
        (file as NSString).lastPathComponent
    }

    public func formatted(includeLocation: Bool = false) -> String {
        let formatter = Self.formatter(for: LogViewer.dateFormat)
        let time = formatter.string(from: timestamp)
        var result = "[\(time)] [\(level.rawValue)] [\(category)] \(message)"
        if includeLocation {
            result += "\n↳ \(fileName):\(line) \(function)"
        }
        return result
    }

    // NSCache is thread-safe; we cache one DateFormatter per format string to
    // avoid building a new formatter for every log line.
    private static let formatterCache = NSCache<NSString, DateFormatter>()

    private static func formatter(for format: String) -> DateFormatter {
        let key = format as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let f = DateFormatter()
        f.dateFormat = format
        formatterCache.setObject(f, forKey: key)
        return f
    }
}
