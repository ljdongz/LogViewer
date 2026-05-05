import Foundation

/// LogViewer 라이브러리의 활성화 토글과 전역 설정을 담는 네임스페이스.
///
/// 이 enum은 인스턴스화하지 않고 정적 멤버를 통해 사용합니다. 라이브러리는
/// "어떻게 띄울지"는 강제하지 않으며, 호스트 앱이 자유롭게 ``LogViewerView``를
/// 띄우면 됩니다. 트리거 패턴은 <doc:PresentationRecipes> 참고.
///
/// ## 활성화
/// 기본값이 `false`이므로 호스트 앱이 명시적으로 켜야 합니다.
///
/// ```swift
/// #if DEBUG
/// LogViewer.isEnabled = true
/// LogViewer.configure {
///     $0.maxLogCount = 1000
///     $0.dateFormat  = "HH:mm:ss.SSS"
/// }
/// #endif
/// ```
///
/// ## Topics
/// ### 활성화
/// - ``isEnabled``
/// ### 설정
/// - ``configure(_:)``
public enum LogViewer {

    // MARK: - Activation Control

    /// 라이브러리 활성화 여부.
    ///
    /// 기본값은 `false`입니다. SPM으로 배포된 라이브러리는 release로 컴파일되므로
    /// 라이브러리 내부의 `#if DEBUG`로는 호스트 앱의 빌드 모드를 알 수 없어,
    /// 활성화는 호스트 앱이 직접 결정해야 합니다.
    ///
    /// `false`인 동안 ``LogStore/log(level:category:message:file:function:line:)``는
    /// no-op으로 동작하므로 release 빌드에서도 호출 비용이 거의 없습니다.
    ///
    /// 활성화 패턴은 <doc:Activation>을 참고하세요.
    public static var isEnabled: Bool = false

    // MARK: - Configuration

    private static var configuration = LogViewerConfiguration()

    /// 전역 ``LogViewerConfiguration``을 갱신합니다.
    ///
    /// `inout` 클로저로 현재 설정을 받아 자유롭게 수정합니다.
    /// ``isEnabled``가 `false`이면 no-op입니다.
    ///
    /// - Parameter block: 설정을 변경하는 클로저.
    ///
    /// ```swift
    /// LogViewer.configure {
    ///     $0.maxLogCount = 2000
    ///     $0.dateFormat  = "yyyy-MM-dd HH:mm:ss"
    /// }
    /// ```
    public static func configure(
        _ block: (inout LogViewerConfiguration) -> Void
    ) {
        guard isEnabled else { return }
        block(&configuration)
        let max = configuration.maxLogCount
        Task { @MainActor in
            LogStore.shared.maxCount = max
        }
    }

    static var dateFormat: String {
        configuration.dateFormat
    }
}
