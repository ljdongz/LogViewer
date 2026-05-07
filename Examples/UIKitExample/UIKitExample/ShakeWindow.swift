import UIKit

/// A custom UIWindow that detects the shake gesture and posts a Notification.
///
/// LogViewer does not provide a trigger; the host app must wire one up.
/// This example demonstrates the shake-to-show pattern.
final class ShakeWindow: UIWindow {
    /// Posted when a shake gesture is detected.
    /// (This name is defined by the example app, not by the LogViewer library.)
    static let didShakeNotification = Notification.Name("ShakeWindow.didShake")

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: ShakeWindow.didShakeNotification, object: self)
        }
    }
}
