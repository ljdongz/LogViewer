# Activation

A summary of when and how to turn `LogViewer.isEnabled` on and off.

## Overview

``LogViewer/LogViewer`` defaults to `isEnabled = false`.
While this value is `false`, ``LogStore/log(level:category:message:file:function:line:)`` becomes a no-op and
retains no entries at all. This is a safeguard against accidentally accumulating debug data in release builds.

### Why isn't this handled with `#if DEBUG` inside the library?

Swift Package Manager almost always builds dependent libraries in release compile mode.
That is, **`#if DEBUG` inside library code does not turn on even when the user's app is built in Debug.**
From the library's perspective, it cannot know the build mode of the app that uses it.

Instead, when you explicitly call `LogViewer.isEnabled = true` from a `#if DEBUG` block on the app side,
the toggle is driven by the user app's build mode, so you can reliably get the "enabled only in debug" behavior.

### Recommended Pattern

Turn it on once at the app's entry point.

```swift
import LogViewer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        LogViewer.isEnabled = true
        LogViewer.configure { config in
            config.maxLogCount = 500
            config.dateFormat = "HH:mm:ss.SSS"
        }
        #endif
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

### Automatically Disabled in TestFlight and Release

No additional work is required. The `#if DEBUG` block is excluded from compilation in Release / TestFlight Archive builds, so
`isEnabled` remains at its default value of `false`.

If you want it enabled in internal QA builds but disabled in external distributions, use a custom compilation flag (for example, `-D INTERNAL_BUILD`).

```swift
#if DEBUG || INTERNAL_BUILD
LogViewer.isEnabled = true
#endif
```

### Runtime Toggle

You can also turn it on and off directly from a debug menu or a hidden settings screen.

```swift
Toggle("In-App Logger", isOn: Binding(
    get: { LogViewer.isEnabled },
    set: { LogViewer.isEnabled = $0 }
))
```

Setting `isEnabled` to `false` immediately makes ``LogStore/log(level:category:message:file:function:line:)`` a no-op and stops new log collection.
Already-captured entries are retained as-is until you call ``LogStore/clear()``.
Setting it back to `true` reuses the same ``LogStore/shared`` instance.
