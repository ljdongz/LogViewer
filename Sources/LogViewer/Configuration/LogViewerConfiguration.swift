import Foundation

public struct LogViewerConfiguration: Sendable {
    /// 최대 보관 로그 수 (기본: 500)
    public var maxLogCount: Int = 500

    /// 타임스탬프 표시 포맷 (기본: "HH:mm:ss.SSS")
    public var dateFormat: String = "HH:mm:ss.SSS"
}
