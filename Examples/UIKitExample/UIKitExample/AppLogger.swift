import Foundation
import LogViewer

final class AppLogger {
    static let shared = AppLogger()

    private let category: String

    init(category: String = "App") {
        self.category = category
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("ℹ️ [\(category)] \(message)")
        LogStore.shared.log(level: .notice, category: category, message: message,
                            file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("⚠️ [\(category)] \(message)")
        LogStore.shared.log(level: .warning, category: category, message: message,
                            file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        print("❌ [\(category)] \(message)")
        LogStore.shared.log(level: .error, category: category, message: message,
                            file: file, function: function, line: line)
    }
}

// MARK: - Dummy Log Seeder

/// Seeds a diverse set of dummy log entries so the log viewer screen has
/// representative content for screenshots and demos. Only meant for the
/// example apps — never call this from a real app.
enum DummyLogSeeder {

    static func seed() {
        let entries: [(LogEntry.Level, String, String)] = [
            (.log,      "App",       "Application bundle loaded"),
            (.notice,   "App",       "Cold start completed in 412ms"),
            (.notice,   "Auth",      "Restoring session for user_id=u_8f2a"),
            (.notice,   "Auth",      "Session restored — token TTL 3540s"),
            (.log,      "Cache",     "Disk cache hit ratio: 0.87"),
            (.notice,   "Cache",     "Memory cache evicted 12 entries (LRU)"),
            (.notice,   "Network",   "GET /api/feed → 200 OK (132ms)"),
            (.notice,   "Network",   "GET /api/profile → 200 OK (87ms)"),
            (.warning,  "Network",   "GET /api/products → 429 Too Many Requests, retry in 2s"),
            (.notice,   "Network",   "POST /api/events → 202 Accepted (210ms)"),
            (.error,    "Network",   "POST /api/orders → 500 Internal Server Error"),
            (.warning,  "UI",        "Image asset 'banner_xl' not found, falling back to default"),
            (.notice,   "UI",        "Rendered HomeView in 18.4ms"),
            (.log,      "UI",        "Pull-to-refresh triggered"),
            (.notice,   "Database",  "Migration v3 → v4 completed (47 rows)"),
            (.warning,  "Database",  "Slow query: SELECT * FROM messages WHERE … (812ms)"),
            (.notice,   "Push",      "APNs token registered: 64-byte token"),
            (.warning,  "Push",      "Notification permission denied"),
            (.notice,   "Analytics", "Event 'screen_view' enqueued"),
            (.notice,   "Analytics", "Flushed 24 events to backend"),
            (.warning,  "Payment",   "Card limit warning: 92% of monthly budget used"),
            (.error,    "Payment",   "Payment failed: card declined (code=card_declined)"),
            (.critical, "Auth",      "Unauthorized request detected from suspicious IP"),
            (.critical, "Database",  "Disk write failed — falling back to in-memory store"),
            (.fault,    "App",       "Unhandled exception in background queue: NSInvalidArgumentException"),
        ]

        for (level, category, message) in entries {
            LogStore.shared.log(level: level, category: category, message: message)
        }
    }
}
