import XCTest
@testable import LogViewer

final class HighlightingTests: XCTestCase {

    // MARK: - LogEntry Level Comparable

    func testLevelSeverityOrder() {
        XCTAssertTrue(LogEntry.Level.log < .notice)
        XCTAssertTrue(LogEntry.Level.notice < .warning)
        XCTAssertTrue(LogEntry.Level.warning < .error)
        XCTAssertTrue(LogEntry.Level.error < .critical)
        XCTAssertTrue(LogEntry.Level.critical < .fault)
    }

    func testLevelComparableNotEqual() {
        XCTAssertFalse(LogEntry.Level.error < .error)
        XCTAssertFalse(LogEntry.Level.warning < .log)
    }

    // MARK: - LogEntry Formatting

    func testFormattedWithoutLocation() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .error,
            category: "Payment",
            message: "Payment failed"
        )
        let formatted = entry.formatted(includeLocation: false)
        XCTAssertTrue(formatted.contains("[ERROR]"))
        XCTAssertTrue(formatted.contains("[Payment]"))
        XCTAssertTrue(formatted.contains("Payment failed"))
        XCTAssertFalse(formatted.contains("↳"))
    }

    func testFormattedWithLocation() {
        let entry = LogEntry(
            timestamp: Date(),
            level: .warning,
            category: "Net",
            message: "timeout",
            file: "/path/to/NetworkService.swift",
            function: "fetch()",
            line: 42
        )
        let formatted = entry.formatted(includeLocation: true)
        XCTAssertTrue(formatted.contains("↳"))
        XCTAssertTrue(formatted.contains("NetworkService.swift"))
        XCTAssertTrue(formatted.contains("42"))
        XCTAssertTrue(formatted.contains("fetch()"))
    }

    // MARK: - LogEntry FileName

    func testFileName() {
        let entry = LogEntry(
            level: .log,
            category: "Test",
            message: "msg",
            file: "/Users/dev/Project/Sources/MyFile.swift"
        )
        XCTAssertEqual(entry.fileName, "MyFile.swift")
    }

    // MARK: - MatchLocation

    func testMatchLocationEquality() {
        let id = UUID()
        let a = MatchLocation(entryId: id, lowerBound: 0, upperBound: 5)
        let b = MatchLocation(entryId: id, lowerBound: 0, upperBound: 5)
        XCTAssertEqual(a, b)
    }

    func testMatchLocationInequality() {
        let a = MatchLocation(entryId: UUID(), lowerBound: 0, upperBound: 5)
        let b = MatchLocation(entryId: UUID(), lowerBound: 0, upperBound: 5)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - LogEntry Identifiable

    func testLogEntryIdentifiable() {
        let entry1 = LogEntry(level: .log, category: "A", message: "msg")
        let entry2 = LogEntry(level: .log, category: "A", message: "msg")
        XCTAssertNotEqual(entry1.id, entry2.id)
    }
}
