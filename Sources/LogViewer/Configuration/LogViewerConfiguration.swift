import Foundation

/// LogViewer 라이브러리의 전역 설정 값.
///
/// ``LogViewer/configure(_:)``의 클로저 안에서 수정합니다. 직접 인스턴스를 만들어
/// 보관할 필요는 없으며, 라이브러리가 내부적으로 단일 설정 인스턴스를 유지합니다.
public struct LogViewerConfiguration: Sendable {
    /// 메모리에 보관할 최대 로그 수. 기본 `500`.
    ///
    /// 로그가 이 값을 초과하면 가장 오래된 항목부터 ring-buffer 형태로 제거됩니다.
    public var maxLogCount: Int = 500

    /// 로그 화면과 export에 사용되는 타임스탬프 포맷. 기본 `"HH:mm:ss.SSS"`.
    ///
    /// `DateFormatter`가 받아들이는 모든 포맷 문자열을 지원합니다.
    public var dateFormat: String = "HH:mm:ss.SSS"
}
