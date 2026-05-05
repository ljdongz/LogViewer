# LogViewer

An in-app log viewer SwiftUI component for iOS apps.
Log capture, search, filter, share, and file export.

## Features

- Log capture (`LogStore`) — level/category/location metadata, ring-buffer (default 500 entries)
- Log screen (`LogViewerView`) — search/highlight, level/category filters, text sharing, `.log` file export
- Lightweight design — the library does not enforce "how to present it"; it provides only the screen component. The app is free to decide how to present it.
- iOS 16+ / SwiftUI / Swift 6.0 toolchain

## Requirements

- iOS 16.0+
- Xcode 15+ (Swift 5.9 or later; Swift 6 toolchain compatible)

## Installation

### Swift Package Manager (Xcode UI)

File → Add Package Dependencies → URL → `https://github.com/<your-repo>/LogViewer`

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/<your-repo>/LogViewer", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "LogViewer", package: "LogViewer"),
            ]
        ),
    ]
)
```

## Activation — Read this first

`LogViewer.isEnabled` defaults to `false`, and **the consuming app must explicitly turn it on** for logs to be captured. This is because SPM libraries are built in release mode, so the library's internal `#if DEBUG` cannot detect the consuming app's build configuration. Call the following inside `#if DEBUG` at your app's entry point.

```swift
import SwiftUI
import LogViewer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        LogViewer.isEnabled = true
        LogViewer.configure {
            $0.maxLogCount = 1000
            $0.dateFormat = "HH:mm:ss.SSS"
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

When `isEnabled == false`, calls to `LogStore.shared.log(...)` are immediately ignored, and `LogViewer.configure { ... }` becomes a no-op as well. So even if the code is included in release builds, the runtime cost is effectively zero.

## Logging

```swift
LogStore.shared.log(level: .notice,  category: "App",     message: "앱 시작")
LogStore.shared.log(level: .warning, category: "Network", message: "429 Too Many Requests")
LogStore.shared.log(level: .error,   category: "Payment", message: "카드 한도 초과")
```

`LogStore.shared.log(...)` is `nonisolated`, so it can be called from any thread (it hops to MainActor internally). No `await` is required at the call site.

`LogEntry.Level` cases: `.log`, `.notice`, `.warning`, `.error`, `.critical`, `.fault` (Comparable).

## Presenting the screen — your choice

This library provides only `LogViewerView()`. When and how to present it is up to the app. A collection of common patterns is summarized below.

### Pattern 1. NavigationLink in a debug menu

```swift
import SwiftUI
import LogViewer

struct DebugMenu: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("로그 보기") { LogViewerView() }
            }
            .navigationTitle("Debug")
        }
    }
}
```

### Pattern 2. Presenting a sheet via a secret gesture (3-tap, long press, etc.)

```swift
import SwiftUI
import LogViewer

struct ContentView: View {
    @State private var showLog = false

    var body: some View {
        MyRootView()
            .onTapGesture(count: 3) { showLog = true }
            .sheet(isPresented: $showLog) { LogViewerView() }
    }
}
```

### Pattern 3. A floating button only in debug builds

```swift
import SwiftUI
import LogViewer

struct RootView: View {
    @State private var showLog = false

    var body: some View {
        ZStack {
            MyRootView()
            #if DEBUG
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .padding()
                            .background(.thinMaterial, in: .circle)
                    }
                    .padding()
                }
            }
            #endif
        }
        .sheet(isPresented: $showLog) { LogViewerView() }
    }
}
```

### Pattern 4. Presenting from UIKit

```swift
import UIKit
import SwiftUI
import LogViewer

final class DebugViewController: UIViewController {
    @IBAction func openLogViewer(_ sender: Any) {
        let vc = UIHostingController(rootView: LogViewerView())
        present(vc, animated: true)
    }
}
```

### Pattern 5. Presenting on shake (UIWindow subclass)

If you want it, add the following 5-line subclass to your app code. The library does not enforce this behavior.

```swift
import UIKit

final class ShakeWindow: UIWindow {
    var onShake: (() -> Void)?

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionBegan(motion, with: event)
        if motion == .motionShake { onShake?() }
    }
}
```

In `SceneDelegate`, create it with `ShakeWindow(windowScene: ws)`, and in `onShake` wrap `LogViewerView()` in a `UIHostingController` and present it. For apps using SwiftUI `WindowGroup`, either inject a SceneDelegate via `UIApplicationDelegateAdaptor`, or use the gesture triggers from patterns 2/3.

## Configuration

`LogViewerConfiguration`:

| Option | Type | Default | Description |
| ---- | ---- | ------ | ---- |
| `maxLogCount` | `Int` | `500` | Maximum ring-buffer capacity. When exceeded, the oldest entries are discarded first. |
| `dateFormat` | `String` | `"HH:mm:ss.SSS"` | Timestamp display format. |

```swift
LogViewer.configure { config in
    config.maxLogCount = 5_000
    config.dateFormat  = "yyyy-MM-dd HH:mm:ss.SSS"
}
```

`LogViewer.configure { ... }` is a no-op when `isEnabled == false`.

## Log export

```swift
let text = LogStore.shared.exportAsText(includeLocation: true)
let url  = LogStore.shared.exportAsLogFile()  // creates a .log file in the tmp directory
```

The share button inside `LogViewerView` uses the same export. In UIKit, passing `text` or `url` to a `UIActivityViewController` opens the system share sheet.

## Data model

- `LogEntry`
  - `id: UUID`
  - `timestamp: Date`
  - `level: LogEntry.Level`
  - `category: String`
  - `message: String`
  - `file: String`, `function: String`, `line: Int`
- `LogEntry.Level`: `.log`, `.notice`, `.warning`, `.error`, `.critical`, `.fault` (Comparable)
- `LogStore`
  - `static let shared`
  - `@Published var entries: [LogEntry]`
  - `var availableCategories: [String]`
  - `nonisolated func log(level:category:message:file:function:line:)`
  - `func clear()`
  - `func exportAsText(includeLocation:) -> String`
  - `func exportAsLogFile(includeLocation:) -> URL`

## Examples

- `Examples/SwiftUIExample` — triggering directly from SwiftUI (sheet/NavigationLink patterns)
- `Examples/UIKitExample` — pattern for presenting via `UIHostingController` from UIKit

You can open each directory's `.xcodeproj` in Xcode and run it directly.

## License

MIT License. See the [LICENSE](./LICENSE) file for details.
