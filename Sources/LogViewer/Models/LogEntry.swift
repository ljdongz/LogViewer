import Foundation

/// A single log entry.
///
/// ``LogStore/log(level:category:message:file:function:line:)`` constructs this internally,
/// so the host app rarely creates one directly. Use it together with ``LogStore/append(_:)``
/// only when recording a log received from an external system.
///
/// ## Topics
/// ### Metadata
/// - ``id``
/// - ``timestamp``
/// - ``level``
/// - ``category``
/// ### Body
/// - ``message``
/// ### Call Site
/// - ``file``
/// - ``function``
/// - ``line``
/// - ``fileName``
/// ### Formatting
/// - ``formatted(includeLocation:)``
/// ### Related Types
/// - ``Level``
public struct LogEntry: Identifiable, Equatable, Sendable {

    /// Log level. Severity increases from ``log`` to ``fault``.
    ///
    /// Conforms to `Comparable`, so threshold comparisons such as `level >= .warning` are
    /// supported.
    public enum Level: String, CaseIterable, Equatable, Comparable, Sendable {
        /// Debug or informational log.
        case log = "LOG"
        /// General notice (info-level).
        case notice = "NOTICE"
        /// Warning. Operation continues but warrants attention.
        case warning = "WARN"
        /// Error. A particular operation has failed.
        case error = "ERROR"
        /// Critical error. Part of the feature is unusable.
        case critical = "CRITICAL"
        /// System-fault-level error.
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

    /// Unique identifier of the entry. Defaults to a freshly generated `UUID`.
    public let id: UUID
    /// The time the entry was created.
    public let timestamp: Date
    /// The log level.
    public let level: Level
    /// Category string (e.g. `"Network"`, `"Auth"`).
    public let category: String
    /// The log body.
    public let message: String
    /// Full path of the calling file (`#file`).
    public let file: String
    /// Calling function signature (`#function`).
    public let function: String
    /// Calling line number (`#line`).
    public let line: Int

    /// Creates a new ``LogEntry``.
    ///
    /// - Parameters:
    ///   - id: Entry identifier. Defaults to a new `UUID`.
    ///   - timestamp: Creation time. Defaults to `Date()`.
    ///   - level: Log level.
    ///   - category: Category string.
    ///   - message: Log body.
    ///   - file: Calling file path (`#file`).
    ///   - function: Calling function (`#function`).
    ///   - line: Calling line (`#line`).
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

    /// Last path component of ``file`` (file name plus extension).
    public var fileName: String {
        (file as NSString).lastPathComponent
    }

    /// Formats the entry as one line — or two lines when location is included.
    ///
    /// The timestamp format follows ``LogViewerConfiguration/dateFormat``.
    /// Output shape:
    /// ```
    /// [HH:mm:ss.SSS] [LEVEL] [Category] message
    /// ↳ FileName.swift:42 function(_:)
    /// ```
    ///
    /// - Parameter includeLocation: If `true`, appends the call site on a second line.
    /// - Returns: The formatted string.
    public func formatted(includeLocation: Bool = false) -> String {
        let formatter = Self.formatter(for: LogViewer.dateFormat)
        let time = formatter.string(from: timestamp)
        var result = "[\(time)] [\(level.rawValue)] [\(category)] \(message)"
        if includeLocation {
            result += "\n↳ \(fileName):\(line) \(function)"
        }
        return result
    }

    // NSCache is thread-safe; cache one DateFormatter per format string to
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
