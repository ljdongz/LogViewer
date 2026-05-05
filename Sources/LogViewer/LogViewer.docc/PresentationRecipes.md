# Presentation Recipes

Five common trigger patterns for presenting `LogViewerView`.

## Overview

LogViewer does not force "when and how to present the screen" from the library.
Each app has different debug-menu policies, and gesture conflicts and accessibility requirements vary as well.

Instead, here is a collection of frequently used trigger recipes. Pick the one you like and paste it directly into your code.
They all present ``LogViewerView`` the same way; only the trigger portion is app code.

### 1. Debug Menu NavigationLink

The simplest and safest approach. Provide entry from a "Developer" section inside a settings screen.

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

### 2. Secret Gesture (long-press / multi-tap)

Attach a long-press gesture to the app logo or an empty area so QA can find it. Regular users are unlikely to discover it by accident.

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

### 3. DEBUG-Only Floating Button

A small button floating in the corner of the screen. It only compiles in debug builds.

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

### 4. UIKit `UIHostingController` Present

When presenting from an existing UIKit screen:

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

Call site:

```swift
@IBAction func didTapLogs(_ sender: Any) {
    presentLogViewer()
}
```

### 5. Shake-to-show

Shake is not a standard SwiftUI gesture, so you need to intercept `motionEnded` on `UIWindow`.
Add a short `UIWindow` subclass to your app.

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

Set up `SceneDelegate` to use `ShakeWindow`.

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

Now in debug builds, shaking the device brings up the log screen as a sheet.
In the simulator, you can trigger it with ⌃⌘Z (Device → Shake).
