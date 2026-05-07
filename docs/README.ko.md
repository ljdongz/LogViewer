# LogViewer

<p align="center">
  <a href="../README.md">🇺🇸 English</a> | 🇰🇷 한국어
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2016%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftPM-compatible-brightgreen" alt="SwiftPM">
</p>

iOS 앱을 위한 인-앱 로그 뷰어 SwiftUI 컴포넌트.
로그 캡처, 검색, 필터, 공유, 파일 export 기능 제공.

<p align="center">
  <img src="screenshot.png" alt="LogViewer 스크린샷" width="320">
</p>

## 목차

- [특징](#특징)
- [요구사항](#요구사항)
- [설치](#설치)
  - [Swift Package Manager (Xcode UI)](#swift-package-manager-xcode-ui)
  - [Package.swift](#packageswift)
- [활성화](#활성화--먼저-읽어주세요)
- [로깅](#로깅)
- [화면 띄우기](#화면-띄우기--직접-결정)
  - [패턴 1. 디버그 메뉴의 NavigationLink](#패턴-1-디버그-메뉴의-navigationlink)
  - [패턴 2. 비밀 제스처로 sheet 띄우기](#패턴-2-비밀-제스처로-sheet-띄우기-3-tap-long-press-등)
  - [패턴 3. DEBUG 빌드 전용 floating 버튼](#패턴-3-debug-빌드-전용-floating-버튼)
  - [패턴 4. UIKit에서 띄우기](#패턴-4-uikit에서-띄우기)
  - [패턴 5. 흔들기로 띄우기 (UIWindow 서브클래스)](#패턴-5-흔들기로-띄우기-uiwindow-서브클래스)
- [Configuration](#configuration)
- [로그 export](#로그-export)
- [데이터 모델](#데이터-모델)
- [Examples](#examples)
- [License](#license)

## 특징

- 로그 캡처 (`LogStore`) — 레벨/카테고리/위치 메타데이터, ring-buffer (기본 500개)
- 로그 화면 (`LogViewerView`) — 검색/하이라이트, 레벨/카테고리 필터, 텍스트 공유, `.log` 파일 export
- 가벼운 디자인 — 라이브러리는 "어떻게 띄울지"를 강제하지 않고 화면 컴포넌트만 제공. 띄우는 방식은 앱이 자유롭게 결정.
- iOS 16+ / SwiftUI / Swift 6.0 toolchain

## 요구사항

- iOS 16.0+
- Xcode 15+ (Swift 5.9 이상; Swift 6 toolchain 호환)

## 설치

### Swift Package Manager (Xcode UI)

File → Add Package Dependencies → URL → `https://github.com/ljdongz/LogViewer`

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/ljdongz/LogViewer", from: "1.0.0"),
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

## 활성화 — 먼저 읽어주세요

`LogViewer.isEnabled`의 기본값은 `false`이며, **로그가 캡처되려면 사용자 앱이 명시적으로 켜야** 합니다. SPM 라이브러리는 release로 빌드되므로 라이브러리 내부의 `#if DEBUG`로는 사용자 앱의 빌드 모드를 알 수 없기 때문입니다. 사용자 앱의 진입점에서 `#if DEBUG` 안에 다음을 호출하세요.

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

`isEnabled == false`이면 `LogStore.shared.log(...)` 호출은 즉시 무시되고, `LogViewer.configure { ... }`도 no-op이 됩니다. 따라서 release 빌드에 코드가 남아있어도 런타임 비용은 사실상 0입니다.

## 로깅

```swift
LogStore.shared.log(level: .notice,  category: "App",     message: "앱 시작")
LogStore.shared.log(level: .warning, category: "Network", message: "429 Too Many Requests")
LogStore.shared.log(level: .error,   category: "Payment", message: "카드 한도 초과")
```

`LogStore.shared.log(...)`는 `nonisolated`라서 어느 스레드에서도 호출 가능합니다 (내부에서 MainActor로 hop). 호출 측에서 `await`은 필요 없습니다.

`LogEntry.Level` 케이스: `.log`, `.notice`, `.warning`, `.error`, `.critical`, `.fault` (Comparable).

## 화면 띄우기 — 직접 결정

이 라이브러리는 `LogViewerView()`만 제공합니다. 띄우는 시점/방식은 앱이 정합니다. 자주 쓰이는 패턴 모음:

### 패턴 1. 디버그 메뉴의 NavigationLink

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

### 패턴 2. 비밀 제스처로 sheet 띄우기 (3-tap, long press 등)

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

### 패턴 3. DEBUG 빌드 전용 floating 버튼

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

### 패턴 4. UIKit에서 띄우기

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

### 패턴 5. 흔들기로 띄우기 (UIWindow 서브클래스)

원하면 다음 5줄짜리 서브클래스를 앱 코드에 추가하세요. 라이브러리는 이 동작을 강제하지 않습니다.

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

`SceneDelegate`에서 `ShakeWindow(windowScene: ws)`로 만들고, `onShake`에서 `LogViewerView()`를 `UIHostingController`로 감싸 present하면 됩니다. SwiftUI `WindowGroup`을 쓰는 앱이라면 `UIApplicationDelegateAdaptor`로 SceneDelegate를 끼우거나, 패턴 2·3의 제스처 트리거를 사용하세요.

## Configuration

`LogViewerConfiguration`:

| 옵션 | 타입 | 기본값 | 설명 |
| ---- | ---- | ------ | ---- |
| `maxLogCount` | `Int` | `500` | ring-buffer 최대 보관 수. 초과 시 가장 오래된 항목부터 제거. |
| `dateFormat` | `String` | `"HH:mm:ss.SSS"` | 타임스탬프 표시 포맷. |

```swift
LogViewer.configure { config in
    config.maxLogCount = 5_000
    config.dateFormat  = "yyyy-MM-dd HH:mm:ss.SSS"
}
```

`LogViewer.configure { ... }`는 `isEnabled == false`이면 no-op입니다.

## 로그 export

```swift
let text = LogStore.shared.exportAsText(includeLocation: true)
let url  = LogStore.shared.exportAsLogFile()  // tmp 디렉토리에 .log 파일 생성
```

`LogViewerView` 내부의 공유 버튼이 동일한 export를 사용합니다. UIKit에서는 `text` 또는 `url`을 `UIActivityViewController`에 넘겨 시스템 공유 시트를 열 수 있습니다.

## 데이터 모델

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

- `Examples/SwiftUIExample` — SwiftUI에서 직접 트리거 (sheet/NavigationLink 패턴)
- `Examples/UIKitExample` — UIKit에서 `UIHostingController`로 띄우는 패턴

각 디렉토리의 `.xcodeproj`를 Xcode로 열어 바로 실행할 수 있습니다.

## License

MIT License. 자세한 내용은 [LICENSE](../LICENSE) 파일을 참고하세요.
