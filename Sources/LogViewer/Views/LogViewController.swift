#if canImport(UIKit)
import UIKit
import SwiftUI

/// UIKit 진입점. ``LogViewerView`` 를 호스팅한 `UIViewController` 입니다.
///
/// UIKit 앱에서는 SwiftUI 의존성을 직접 다룰 필요 없이 일반 `UIViewController` 처럼
/// `present(_:animated:)` 또는 `pushViewController(_:animated:)` 로 띄우면 됩니다.
/// 호스팅된 ``LogViewerView`` 가 자체 `NavigationStack` 과 닫기 버튼을 포함하므로
/// 추가로 `UINavigationController` 로 감쌀 필요는 없습니다.
///
/// ```swift
/// // 시트로 표시
/// let vc = LogViewController()
/// if let sheet = vc.sheetPresentationController {
///     sheet.detents = [.large()]
///     sheet.prefersGrabberVisible = true
/// }
/// present(vc, animated: true)
/// ```
public final class LogViewController: UIHostingController<LogViewerView> {

    /// 새 ``LogViewController`` 를 생성합니다.
    public init() {
        super.init(rootView: LogViewerView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: LogViewerView())
    }
}
#endif
