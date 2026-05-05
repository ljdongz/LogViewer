import Foundation

/// 단일 로그 항목.
///
/// ``LogStore/log(level:category:message:file:function:line:)``가 내부에서 자동으로
/// 생성하므로 호스트 앱이 직접 이 타입을 만들 일은 거의 없습니다. 외부 시스템에서
/// 받은 로그를 직접 적재할 때만 ``LogStore/append(_:)``와 함께 사용합니다.
///
/// ## Topics
/// ### 메타데이터
/// - ``id``
/// - ``timestamp``
/// - ``level``
/// - ``category``
/// ### 본문
/// - ``message``
/// ### 호출 위치
/// - ``file``
/// - ``function``
/// - ``line``
/// - ``fileName``
/// ### 포맷팅
/// - ``formatted(includeLocation:)``
/// ### 관련 타입
/// - ``Level``
public struct LogEntry: Identifiable, Equatable, Sendable {

    /// 로그 레벨. 심각도 순으로 ``log`` → ``fault``로 증가합니다.
    ///
    /// `Comparable`을 채택하므로 `level >= .warning`처럼 임계값 비교가 가능합니다.
    public enum Level: String, CaseIterable, Equatable, Comparable, Sendable {
        /// 디버그/정보성 로그.
        case log = "LOG"
        /// 일반 통지 (info 수준).
        case notice = "NOTICE"
        /// 경고. 동작은 계속되지만 주의가 필요.
        case warning = "WARN"
        /// 오류. 특정 동작이 실패한 상태.
        case error = "ERROR"
        /// 치명적 오류. 기능 일부가 동작 불가.
        case critical = "CRITICAL"
        /// 시스템 결함 수준의 오류.
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

    /// 항목 고유 식별자. 기본값은 새로 생성된 `UUID`.
    public let id: UUID
    /// 항목 생성 시각.
    public let timestamp: Date
    /// 로그 레벨.
    public let level: Level
    /// 카테고리 문자열 (예: "Network", "Auth").
    public let category: String
    /// 로그 본문.
    public let message: String
    /// 호출 파일의 전체 경로 (`#file`).
    public let file: String
    /// 호출 함수 시그니처 (`#function`).
    public let function: String
    /// 호출 라인 번호 (`#line`).
    public let line: Int

    /// 새 ``LogEntry``를 만듭니다.
    ///
    /// - Parameters:
    ///   - id: 항목 식별자. 기본값은 새 `UUID`.
    ///   - timestamp: 생성 시각. 기본값은 `Date()`.
    ///   - level: 로그 레벨.
    ///   - category: 카테고리 문자열.
    ///   - message: 로그 본문.
    ///   - file: 호출 파일 경로 (`#file`).
    ///   - function: 호출 함수 (`#function`).
    ///   - line: 호출 라인 (`#line`).
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

    /// ``file`` 경로의 마지막 컴포넌트(파일명 + 확장자).
    public var fileName: String {
        (file as NSString).lastPathComponent
    }

    /// 항목을 한 줄 (또는 위치 정보 포함 시 두 줄) 텍스트로 포맷팅합니다.
    ///
    /// 타임스탬프 포맷은 ``LogViewerConfiguration/dateFormat``을 따릅니다.
    /// 결과 형태:
    /// ```
    /// [HH:mm:ss.SSS] [LEVEL] [Category] message
    /// ↳ FileName.swift:42 function(_:)
    /// ```
    ///
    /// - Parameter includeLocation: `true`이면 두 번째 줄에 호출 위치를 덧붙입니다.
    /// - Returns: 포맷팅된 문자열.
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
