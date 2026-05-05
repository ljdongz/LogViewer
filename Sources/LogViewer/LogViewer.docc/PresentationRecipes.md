# Presentation Recipes

`LogViewerView`를 띄우는 흔한 트리거 패턴 5가지.

## Overview

LogViewer는 "언제·어떻게 화면을 띄울지"를 라이브러리가 강제하지 않습니다.
앱마다 디버그 메뉴 정책이 다르고, 제스처 충돌·접근성 요구사항도 제각각이기 때문입니다.

대신 자주 쓰이는 트리거 레시피를 모았습니다. 마음에 드는 것을 골라 자기 코드에 그대로 붙여 넣으면 됩니다.
모두 ``LogViewerView``를 띄운다는 점만 같고, 트리거 부분은 앱 코드입니다.

### 1. 디버그 메뉴 NavigationLink

가장 단순하고 안전한 방법. 설정 화면 안 "Developer" 섹션에서 진입하도록 합니다.

```swift
import SwiftUI
import LogViewer

struct DeveloperMenu: View {
    var body: some View {
        List {
            Section("Diagnostics") {
                NavigationLink("In-App Logs") {
                    LogViewerView()
                }
            }
        }
        .navigationTitle("Developer")
    }
}
```

### 2. 비밀 제스처 (long-press / 다중 탭)

QA가 알 수 있도록 앱 로고나 빈 영역에 long-press 제스처를 겁니다. 일반 사용자가 우연히 발견할 확률이 낮습니다.

```swift
import SwiftUI
import LogViewer

struct RootView: View {
    @State private var showLog = false

    var body: some View {
        ContentView()
            .onLongPressGesture(minimumDuration: 2.0) {
                #if DEBUG
                showLog = true
                #endif
            }
            .sheet(isPresented: $showLog) {
                LogViewerView()
            }
    }
}
```

### 3. DEBUG 빌드 전용 floating button

화면 모서리에 떠 있는 작은 버튼. 디버그 빌드에서만 컴파일됩니다.

```swift
import SwiftUI
import LogViewer

struct RootView: View {
    @State private var showLog = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ContentView()

            #if DEBUG
            Button {
                showLog = true
            } label: {
                Image(systemName: "doc.text.magnifyingglass")
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding()
            #endif
        }
        .sheet(isPresented: $showLog) {
            LogViewerView()
        }
    }
}
```

### 4. UIKit `UIHostingController` present

기존 UIKit 화면에서 띄울 때:

```swift
import UIKit
import SwiftUI
import LogViewer

extension UIViewController {
    func presentLogViewer() {
        let host = UIHostingController(rootView: LogViewerView())
        host.modalPresentationStyle = .pageSheet
        present(host, animated: true)
    }
}
```

호출부:

```swift
@IBAction func didTapLogs(_ sender: Any) {
    presentLogViewer()
}
```

### 5. 흔들기 (Shake-to-show)

흔들기는 SwiftUI 표준 제스처가 아니라 `UIWindow`의 `motionEnded`를 가로채야 합니다.
짧은 `UIWindow` 서브클래스를 자기 앱에 추가하세요.

```swift
import UIKit

final class ShakeWindow: UIWindow {
    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake { onShake?() }
    }
}
```

`SceneDelegate`에서 `ShakeWindow`를 사용하도록 셋업합니다.

```swift
import UIKit
import SwiftUI
import LogViewer

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) {
        guard let scene = scene as? UIWindowScene else { return }

        let window = ShakeWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: ContentView())

        #if DEBUG
        window.onShake = { [weak window] in
            let host = UIHostingController(rootView: LogViewerView())
            window?.rootViewController?.present(host, animated: true)
        }
        #endif

        self.window = window
        window.makeKeyAndVisible()
    }
}
```

이제 디버그 빌드에서 기기를 흔들면 로그 화면이 sheet로 올라옵니다.
시뮬레이터에서는 ⌃⌘Z (Device → Shake)로 트리거할 수 있습니다.
