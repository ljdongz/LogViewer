import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // Use ShakeWindow (instead of UIWindow) to detect the shake gesture.
        let window = ShakeWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
