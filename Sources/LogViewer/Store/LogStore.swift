import Foundation
import Combine

/// 메모리 기반 로그 저장소. ``LogViewerView``의 데이터 소스이자 호스트 앱이
/// 로그를 적재하는 진입점입니다.
///
/// ``shared`` 싱글톤을 통해 사용하며, ``log(level:category:message:file:function:line:)``
/// 한 번의 호출로 ``LogEntry``를 적재합니다. ``LogViewer/isEnabled``가 `false`이면
/// 적재는 no-op으로 동작합니다.
///
/// 저장소는 ring-buffer 정책을 따르며, 항목 수가
/// ``LogViewerConfiguration/maxLogCount``를 초과하면 가장 오래된 항목부터 제거됩니다.
///
/// ``LogStore``는 `@MainActor`로 격리되어 있어 ``entries`` 변경이 항상 메인 스레드에서
/// 일어나며, SwiftUI의 `@Published` 갱신도 안전합니다. 호출 편의를 위해
/// ``log(level:category:message:file:function:line:)``는 `nonisolated`로 노출되어
/// 어떤 스레드에서도 호출 가능합니다.
///
/// ## Topics
/// ### 싱글톤
/// - ``shared``
/// ### 로그 적재
/// - ``log(level:category:message:file:function:line:)``
/// - ``append(_:)``
/// - ``clear()``
/// ### 데이터 접근
/// - ``entries``
/// - ``availableCategories``
/// ### Export
/// - ``exportAsText(includeLocation:)``
/// - ``exportAsLogFile(includeLocation:)``
@MainActor
public final class LogStore: ObservableObject {

    /// 라이브러리가 사용하는 단일 ``LogStore`` 인스턴스.
    public static let shared = LogStore()

    /// 현재 보관 중인 로그 항목. SwiftUI 뷰가 `@Published`로 관찰합니다.
    @Published public private(set) var entries: [LogEntry] = []
    var maxCount: Int = 500

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private init() {}

    // MARK: - Write

    /// 어느 스레드에서도 호출 가능한 로그 적재 진입점.
    ///
    /// 호출 시점에 ``LogEntry``를 만든 뒤 메인 액터로 hop해 ``append(_:)``를
    /// 호출합니다. ``LogViewer/isEnabled``가 `false`이면 적재 단계에서 즉시 반환합니다.
    ///
    /// - Parameters:
    ///   - level: 로그 레벨. 기본 ``LogEntry/Level/log``.
    ///   - category: 카테고리 문자열. 기본 `"Default"`.
    ///   - message: 로그 본문.
    ///   - file: 호출 파일 경로. 기본은 `#file`.
    ///   - function: 호출 함수 시그니처. 기본은 `#function`.
    ///   - line: 호출 라인. 기본은 `#line`.
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

    /// 이미 만들어진 ``LogEntry``를 직접 적재합니다.
    ///
    /// 보통은 ``log(level:category:message:file:function:line:)``를 사용하면 충분합니다.
    /// 외부 시스템에서 받은 항목을 그대로 적재하거나 테스트에서 직접 주입할 때 사용합니다.
    public func append(_ entry: LogEntry) {
        entries.append(entry)
        if entries.count > maxCount {
            entries.removeFirst(entries.count - maxCount)
        }
    }

    // MARK: - Clear

    /// 보관 중인 모든 로그를 비웁니다.
    public func clear() {
        entries.removeAll()
    }

    // MARK: - Export

    /// 보관된 로그 전체를 한 줄씩 줄바꿈으로 이은 문자열로 반환합니다.
    ///
    /// - Parameter includeLocation: `true`이면 각 항목 아래에 호출 파일/라인/함수 정보를 한 줄 더 붙입니다.
    /// - Returns: export용 텍스트.
    public func exportAsText(includeLocation: Bool = true) -> String {
        entries.map { $0.formatted(includeLocation: includeLocation) }.joined(separator: "\n")
    }

    /// 보관된 로그를 임시 디렉토리의 `.log` 파일로 저장하고 URL을 반환합니다.
    ///
    /// 파일 이름은 `logs_yyyy-MM-dd_HH-mm-ss.log` 형태입니다.
    /// 쓰기 실패 시에도 URL은 반환되므로 호출 측에서 파일 존재 여부를 확인할 수 있습니다.
    ///
    /// - Parameter includeLocation: ``exportAsText(includeLocation:)``와 동일.
    /// - Returns: 저장된 파일의 `URL`.
    public func exportAsLogFile(includeLocation: Bool = true) -> URL {
        let text = exportAsText(includeLocation: includeLocation)
        let timestamp = Self.fileNameFormatter.string(from: Date())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("logs_\(timestamp).log")
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Query

    /// 현재 ``entries``에 등장하는 카테고리들을 알파벳 순으로 정렬해 반환합니다.
    ///
    /// ``LogViewerView``의 카테고리 필터 UI가 이 값을 사용합니다.
    public var availableCategories: [String] {
        Array(Set(entries.map(\.category))).sorted()
    }
}
