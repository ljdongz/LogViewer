import XCTest
@testable import LogViewer

final class LogStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LogViewer.isEnabled = true
        LogStore.shared.clear()
    }

    override func tearDown() {
        LogStore.shared.clear()
        super.tearDown()
    }

    // MARK: - Basic Append

    func testAppendAddsEntry() {
        let entry = LogEntry(level: .log, category: "Test", message: "hello")
        LogStore.shared.append(entry)

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            XCTAssertEqual(LogStore.shared.entries.count, 1)
            XCTAssertEqual(LogStore.shared.entries.first?.message, "hello")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Log Convenience Method

    func testLogConvenienceMethod() {
        LogStore.shared.log(level: .error, category: "Net", message: "timeout")

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            XCTAssertEqual(LogStore.shared.entries.count, 1)
            let entry = LogStore.shared.entries.first
            XCTAssertEqual(entry?.level, .error)
            XCTAssertEqual(entry?.category, "Net")
            XCTAssertEqual(entry?.message, "timeout")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Circular Buffer

    func testCircularBufferTrimsOldEntries() {
        LogStore.shared.maxCount = 5

        for i in 0..<10 {
            LogStore.shared.append(LogEntry(level: .log, category: "Test", message: "msg-\(i)"))
        }

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            XCTAssertEqual(LogStore.shared.entries.count, 5)
            XCTAssertEqual(LogStore.shared.entries.first?.message, "msg-5")
            XCTAssertEqual(LogStore.shared.entries.last?.message, "msg-9")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Clear

    func testClearRemovesAllEntries() {
        LogStore.shared.append(LogEntry(level: .log, category: "Test", message: "a"))
        LogStore.shared.append(LogEntry(level: .log, category: "Test", message: "b"))
        LogStore.shared.clear()

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            XCTAssertTrue(LogStore.shared.entries.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Export

    func testExportAsText() {
        LogStore.shared.append(LogEntry(
            timestamp: Date(),
            level: .error,
            category: "App",
            message: "fail"
        ))

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            let text = LogStore.shared.exportAsText(includeLocation: false)
            XCTAssertTrue(text.contains("[ERROR]"))
            XCTAssertTrue(text.contains("[App]"))
            XCTAssertTrue(text.contains("fail"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testExportAsLogFileCreatesFile() {
        LogStore.shared.append(LogEntry(level: .log, category: "Test", message: "hello"))

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            let url = LogStore.shared.exportAsLogFile()
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertTrue(url.lastPathComponent.hasSuffix(".log"))
            try? FileManager.default.removeItem(at: url)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - Available Categories

    func testAvailableCategories() {
        LogStore.shared.append(LogEntry(level: .log, category: "Network", message: "a"))
        LogStore.shared.append(LogEntry(level: .log, category: "Auth", message: "b"))
        LogStore.shared.append(LogEntry(level: .log, category: "Network", message: "c"))

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            let categories = LogStore.shared.availableCategories
            XCTAssertEqual(categories, ["Auth", "Network"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - isEnabled Guard

    func testLogDoesNothingWhenDisabled() {
        LogViewer.isEnabled = false
        LogStore.shared.log(level: .log, category: "Test", message: "should not appear")

        let expectation = expectation(description: "Main queue")
        DispatchQueue.main.async {
            XCTAssertTrue(LogStore.shared.entries.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
