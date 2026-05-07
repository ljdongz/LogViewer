# Getting Started

Four steps to add LogViewer to your project and present your first log on screen.

## Overview

LogViewer is distributed as a Swift Package and supports iOS 16 and later.
The library only provides **log capture** and the **log screen** — your app decides when to present the screen.

### 1. Add the Swift Package

Enter the repository URL in Xcode under File → Add Package Dependencies, or
add it to the dependencies of your `Package.swift`.

```swift
.package(url: "https://github.com/your-org/LogViewer.git", from: "1.0.0")
```

Also add `LogViewer` to your target's dependencies.

```swift
.target(
    name: "MyApp",
    dependencies: ["LogViewer"]
)
```

### 2. Activate in Debug Builds

For safety, LogViewer defaults to disabled. Call ``LogViewer/LogViewer/setup(_:)`` inside `#if DEBUG`
at your app's entry point. See <doc:Activation> for the detailed rationale.

```swift
import LogViewer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        LogViewer.setup { config in
            config.maxLogCount = 1000
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

The closure is optional — call `LogViewer.setup()` to activate with default configuration.

### 3. Call the Logger

Record logs anywhere via ``LogStore``'s `shared`. It is `nonisolated`, so it is safe to call from any thread.

```swift
import LogViewer

LogStore.shared.log(
    level: .notice,
    category: "Auth",
    message: "Login succeeded"
)
```

### 4. Present the Screen

The simplest form — a SwiftUI sheet:

```swift
struct ContentView: View {
    @State private var showLog = false

    var body: some View {
        Button("Show Logs") { showLog = true }
            .sheet(isPresented: $showLog) {
                LogViewerView()
            }
    }
}
```

Tapping the button now brings up the log screen with search, filtering, sharing, and export.

For more trigger patterns such as shake, secret gestures, or a debug menu, see <doc:PresentationRecipes>.
