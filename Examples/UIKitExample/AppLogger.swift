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
