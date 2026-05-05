# Getting Started

LogViewer를 프로젝트에 추가하고 첫 로그를 화면에 띄우기까지의 4단계.

## Overview

LogViewer는 Swift Package로 배포되며 iOS 16 이상을 지원합니다.
라이브러리는 **로그 캡처**와 **로그 화면**만 제공합니다 — 화면을 언제 띄울지는 앱이 결정합니다.

### 1. Swift Package 추가

Xcode의 File → Add Package Dependencies에서 저장소 URL을 입력하거나,
`Package.swift`의 dependencies에 추가합니다.

```swift
.package(url: "https://github.com/your-org/LogViewer.git", from: "1.0.0")
```

타깃의 dependencies에도 `LogViewer`를 추가합니다.

```swift
.target(
    name: "MyApp",
    dependencies: ["LogViewer"]
)
```

### 2. 디버그 빌드에서 활성화

LogViewer는 안전을 위해 기본값이 비활성(`isEnabled = false`)입니다.
앱 시작 지점에서 `#if DEBUG`로 감싸 켜 주세요. 자세한 이유는 <doc:Activation>을 보세요.

```swift
import LogViewer

@main
struct MyApp: App {
    init() {
        #if DEBUG
        LogViewer.isEnabled = true
        LogViewer.configure { config in
            config.maxLogCount = 1000
        }
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### 3. 로그 호출

어디서든 ``LogStore``의 `shared`로 로그를 기록합니다. `nonisolated`라 어느 스레드에서나 안전합니다.

```swift
import LogViewer

LogStore.shared.log(
    level: .notice,
    category: "Auth",
    message: "Login succeeded"
)
```

### 4. 화면 띄우기

가장 단순한 형태 — SwiftUI sheet:

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

이제 버튼을 누르면 검색·필터·공유·export가 가능한 로그 화면이 뜹니다.

흔들기·비밀 제스처·디버그 메뉴 등 트리거 패턴이 더 필요하면 <doc:PresentationRecipes>를 참고하세요.
