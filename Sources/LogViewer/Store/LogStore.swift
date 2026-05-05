import Foundation
import Combine

/// In-memory log store. Both the data source for ``LogViewerView`` and the entry point
/// the host app uses to record logs.
///
/// Use it through the ``shared`` singleton; a single call to
/// ``log(level:category:message:file:function:line:)`` records a ``LogEntry``.
/// Recording is a no-op while ``LogViewer/isEnabled`` is `false`.
///
/// The store follows a ring-buffer policy: once the entry count exceeds
/// ``LogViewerConfiguration/maxLogCount``, the oldest entries are dropped first.
///
/// ``LogStore`` is isolated to `@MainActor`, so mutations to ``entries`` always happen on
/// the main thread and SwiftUI's `@Published` updates remain safe. For convenience,
/// ``log(level:category:message:file:function:line:)`` is exposed as `nonisolated` and can
/// be called from any thread.
///
/// ## Topics
/// ### Singleton
/// - ``shared``
/// ### Recording
/// - ``log(level:category:message:file:function:line:)``
/// - ``append(_:)``
/// - ``clear()``
/// ### Data Access
/// - ``entries``
/// - ``availableCategories``
/// ### Export
/// - ``exportAsText(includeLocation:)``
/// - ``exportAsLogFile(includeLocation:)``
@MainActor
public final class LogStore: ObservableObject {

    /// The single ``LogStore`` instance used by the library.
    public static let shared = LogStore()

    /// The currently retained log entries. Observed by SwiftUI views via `@Published`.
    @Published public private(set) var entries: [LogEntry] = []
    var maxCount: Int = 500

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private init() {}

    // MARK: - Write

    /// Recording entry point that is callable from any thread.
    ///
    /// Builds a ``LogEntry`` at the call site, then hops to the main actor to invoke
    /// ``append(_:)``. Returns immediately at the recording stage when
    /// ``LogViewer/isEnabled`` is `false`.
    ///
    /// - Parameters:
    ///   - level: Log level. Defaults to ``LogEntry/Level/log``.
    ///   - category: Category string. Defaults to `"Default"`.
    ///   - message: The log body.
    ///   - file: Calling file path. Defaults to `#file`.
    ///   - function: Calling function signature. Defaults to `#function`.
    ///   - line: Calling line. Defaults to `#line`.
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

    /// Records an already-constructed ``LogEntry`` directly.
    ///
    /// ``log(level:category:message:file:function:line:)`` is normally sufficient. Use this
    /// when recording an entry received from an external system or when injecting one
    /// directly in tests.
    public func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxCount {
            entries.removeFirst(entries.count - maxCount)
        }
    }

    // MARK: - Clear

    /// Clears all retained logs.
    public func clear() {
        entries.removeAll()
    }

    // MARK: - Export

    /// Returns every retained log joined into a single string, one entry per line.
    ///
    /// - Parameter includeLocation: If `true`, appends an additional line under each entry
    ///   with the calling file/line/function.
    /// - Returns: The text suitable for export.
    public func exportAsText(includeLocation: Bool = true) -> String {
        entries.map { $0.formatted(includeLocation: includeLocation) }.joined(separator: "\n")
    }

    /// Saves the retained logs to a `.log` file in the temporary directory and returns its URL.
    ///
    /// The file name has the form `logs_yyyy-MM-dd_HH-mm-ss.log`.
    /// The URL is returned even on write failure, so callers can verify whether the file
    /// exists.
    ///
    /// - Parameter includeLocation: Same as ``exportAsText(includeLocation:)``.
    /// - Returns: The `URL` of the saved file.
    public func exportAsLogFile(includeLocation: Bool = true) -> URL {
        let text = exportAsText(includeLocation: includeLocation)
        let timestamp = Self.fileNameFormatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logs_\(timestamp).log")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Query

    /// The categories currently present in ``entries``, sorted alphabetically.
    ///
    /// The category filter UI in ``LogViewerView`` consumes this value.
    public var availableCategories: [String] {
        Array(Set(entries.map(\.category))).sorted()
    }
}
