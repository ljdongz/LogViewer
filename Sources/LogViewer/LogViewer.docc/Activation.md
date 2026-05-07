# Activation

How and when to activate LogViewer in your host app.

## Overview

``LogViewer/LogViewer`` ships disabled by default. Until you call ``LogViewer/LogViewer/setup(_:)``,
``LogStore/log(level:category:message:file:function:line:)`` is a no-op and retains no entries at all.
This is a safeguard against accidentally accumulating debug data in release builds.

### Why isn't this handled with `#if DEBUG` inside the library?

Swift Package Manager almost always builds dependent libraries in release compile mode.
That is, **`#if DEBUG` inside library code does not turn on even when the user's app is built in Debug.**
From the library's perspective, it cannot know the build mode of the app that uses it.

Instead, when you explicitly call `LogViewer.setup { ... }` from a `#if DEBUG` block on the app side,
activation is driven by the user app's build mode, so you can reliably get the "enabled only in debug" behavior.

### Recommended Pattern

Activate once at the app's entry point. Pass an optional closure to configure the library at the same time.

```swift
import LogViewer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        LogViewer.setup { config in
            config.maxLogCount = 500
            config.dateFormat = "HH:mm:ss.SSS"
        }
        #endif
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

If you don't need to override the defaults, call `setup` with no arguments:

```swift
#if DEBUG
LogViewer.setup()
#endif
```

### Automatically Disabled in TestFlight and Release

No additional work is required. The `#if DEBUG` block is excluded from compilation in Release / TestFlight Archive builds, so
``LogViewer/LogViewer/isEnabled`` remains at its default value of `false`.

If you want it enabled in internal QA builds but disabled in external distributions, use a custom compilation flag (for example, `-D INTERNAL_BUILD`).

```swift
#if DEBUG || INTERNAL_BUILD
LogViewer.setup()
#endif
```

### Activation is One-Way

``LogViewer/LogViewer/isEnabled`` is exposed as read-only — its setter is `internal`, so you
cannot toggle it from the host app. This is intentional: in practice there is no real-world need
to disable the library at runtime, and a one-way activation API removes a class of misuse
(forgetting to re-enable, racing with the activation callsite, etc.).

If you need to skip work conditionally, gate the call to ``setup(_:)`` with whatever build flag
or runtime condition you like; the library's public surface stays consistent regardless.

### Updating Configuration Later

Calling ``LogViewer/LogViewer/setup(_:)`` again is supported and simply updates the configuration:

```swift
LogViewer.setup { $0.maxLogCount = 1000 }
// ...later, in a debug menu...
LogViewer.setup { $0.maxLogCount = 5000 }
```

The first call activates the library; subsequent calls only adjust configuration.
