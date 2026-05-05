import Foundation

/// Global configuration values for the LogViewer library.
///
/// Mutate this inside the closure of ``LogViewer/configure(_:)``. There is no need to
/// create or hold an instance yourself — the library keeps a single configuration
/// instance internally.
public struct LogViewerConfiguration: Sendable {
    /// Maximum number of log entries kept in memory. Defaults to `500`.
    ///
    /// When the count exceeds this value, the oldest entries are dropped in a ring-buffer
    /// fashion.
    public var maxLogCount: Int = 500

    /// Timestamp format used by the log screen and exports. Defaults to `"HH:mm:ss.SSS"`.
    ///
    /// Supports any format string accepted by `DateFormatter`.
    public var dateFormat: String = "HH:mm:ss.SSS"
}
