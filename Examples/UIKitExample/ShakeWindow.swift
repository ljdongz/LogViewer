import UIKit

/// 흔들기(shake) 동작을 감지하여 Notification 을 발송하는 커스텀 UIWindow.
///
/// LogViewer 라이브러리는 트리거를 제공하지 않으므로, 앱이 직접 트리거를
/// 구현해야 합니다. 이 예제는 흔들기 패턴의 참고 구현입니다.
final class ShakeWindow: UIWindow {
    /// 흔들기 동작이 감지되면 발송되는 Notification.
    /// (라이브러리가 아닌, 앱(예제) 내부에서 정의한 이름입니다.)
    static let didShakeNotification = Notification.Name("ShakeWindow.didShake")

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: ShakeWindow.didShakeNotification, object: self)
        }
    }
}
