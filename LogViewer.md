# LogViewer 설계 문서

> **앱 내에서 로컬 로그를 조회·검색·공유할 수 있는 DEV 전용 로그 뷰어**
>
> Shake 제스처 또는 코드 호출로 트리거되며, 로깅 백엔드(print, os.Logger, swift-log 등)에 관계없이 `LogStore`에 기록된 로그를 리스트 형태로 보여준다. SwiftUI와 UIKit 모두 지원하며, 프로덕션 빌드에는 어떤 코드도 포함되지 않도록 컴파일 타임에 차단된다.

---

## 목차

1. [개요](#1-개요)
2. [설계 원칙](#2-설계-원칙)
3. [아키텍처](#3-아키텍처)
4. [모듈별 상세 설계](#4-모듈별-상세-설계)
5. [핵심 기능 상세](#5-핵심-기능-상세)
6. [사용법](#6-사용법)
7. [SPM 패키지화 가이드](#7-spm-패키지화-가이드)
8. [제약 사항과 알려진 이슈](#8-제약-사항과-알려진-이슈)
9. [확장 아이디어](#9-확장-아이디어)
10. [참고 자료](#10-참고-자료)

---

## 1. 개요

### 1.1 해결하는 문제

iOS 앱을 **TestFlight나 내부 배포 빌드로 QA**할 때는 Xcode 콘솔을 사용할 수 없다. Console.app을 이용하면 OSLog에 기록된 로그를 확인할 수 있지만, QA 담당자의 PC에서 Mac이 없거나, 원격에서 재현이 어렵거나, Apple ID 페어링이 번거로운 경우가 많다. 결과적으로 "버그가 재현됐는데 로그를 얻을 방법이 없다"는 상황이 흔하다.

LogViewer는 이 문제를 해결하기 위해 **앱 내부에 로그 뷰어 화면을 포함**시키고, **물리적으로 기기를 흔드는 제스처**만으로 언제 어디서나 로그를 확인할 수 있도록 한다.

### 1.2 목표(Goals)

- ✅ **로깅 백엔드에 무관하게 로그 수집** — print, os.Logger, swift-log 등 어떤 방식이든 `LogStore.shared.log()` 한 줄로 뷰어에 기록
- ✅ **SwiftUI와 UIKit 모두 지원** — SwiftUI는 `.logViewer()` modifier, UIKit은 `LogViewer.install()` / `LogViewer.show(from:)`
- ✅ **Shake 제스처로 어느 화면에서도 접근** 가능 + 코드에서 직접 호출(programmatic trigger)도 지원
- ✅ **프로덕션 빌드에는 코드 자체가 포함되지 않음** — 바이너리 크기, 메모리, 프라이버시 모두 안전
- ✅ **필터/검색/하이라이트/공유** 등 개발자 친화적 UX
- ✅ **외부 의존성 없음** — SwiftUI + UIKit만 사용
- ✅ **Configuration API로 동작 커스터마이징** — 최대 로그 수, 트리거 방식, 날짜 포맷 등

### 1.3 비목표(Non-goals)

- ❌ 원격 로그 수집(서버 전송) — 별도 프로젝트 영역
- ❌ 크래시 리포팅 — Firebase Crashlytics 등 전용 도구 사용 권장
- ❌ 파일 기반 영속화 — 앱 재시작 시 로그 휘발 (메모리만 사용)
- ❌ 모든 OSLogEntry 조회 — 현재는 직접 append한 로그만 수집 (OSLogStore 미사용)
- ❌ **로거 래퍼 제공** — 라이브러리는 콘솔 출력(print, os.Logger 등)에 관여하지 않음. 뷰어에 보여줄 로그를 수집하는 것이 유일한 책임

---

## 2. 설계 원칙

| 원칙 | 설명 |
|---|---|
| **Zero production cost** | 프로덕션 빌드에는 타입 선언조차 없어야 한다. 사용자가 `#if DEBUG`로 import를 감싸면 바이너리에서 완전히 제거된다. |
| **Backend-agnostic collection** | LogStore는 콘솔 출력에 관여하지 않는다. 어떤 로거(print, os.Logger, swift-log, 커스텀)를 쓰든 `LogStore.shared.log()` 호출만으로 뷰어에 기록된다. 콘솔 출력과 뷰어 기록은 사용자가 각자의 로거에서 독립적으로 수행한다. |
| **SwiftUI + UIKit 1급 지원** | SwiftUI는 `.logViewer()` ViewModifier, UIKit은 `LogViewer.install()` + `LogViewer.show(from:)`으로 동일한 기능을 제공한다. 뷰 구현은 SwiftUI, UIKit 노출은 UIHostingController 래핑. |
| **Broadcast over coupling** | Shake 감지는 `NotificationCenter`로 브로드캐스트하여 수신자(SwiftUI View / UIKit VC)와 느슨하게 결합한다. |
| **Stateless view, stateful store** | View는 상태를 소유하지 않고 `LogStore`라는 중앙 저장소를 관찰한다. |
| **Thread-safe append** | 어느 스레드에서 로깅해도 메인 스레드 큐로 dispatch되어 SwiftUI 관찰이 안전하다. |
| **Graceful degradation** | 필수 기능이 없는 환경(예: 시뮬레이터에서 햅틱)에서 silent하게 실패한다. |

---

## 3. 아키텍처

### 3.1 컴포넌트 다이어그램

```
┌─────────────────────────────────────────────────────────┐
│                       App Code                          │
│                                                         │
│   print("…")    osLogger.info("…")   swiftLog.info("…") │
│       │                │                    │           │
│       ▼                ▼                    ▼           │
│   [콘솔 출력 — 사용자 책임, 라이브러리 영역 밖]          │
│                                                         │
│   LogStore.shared.log(level: .info, category: "Net",    │
│                        message: "request sent")         │
│        │                                                │
└────────┼────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────┐
│      LogStore        │
│  (circular buffer    │
│   @Observable)       │
└──────────┬───────────┘
           │
           │ observed
           ▼
┌─────────────────────────────────────────────────────────┐
│                   LogViewerView                          │
│  (filter, search, highlight, share, navigation)          │
└─────────────────────────────────────────────────────────┘
           ▲
           │ presented by
           │
    ┌──────┴──────┐
    │             │
┌───▼───┐   ┌────▼────────────────────┐
│SwiftUI│   │       UIKit             │
│       │   │                         │
│.logViewer()│ LogViewer.install()    │
│modifier│   │ LogViewer.show(from:)  │
└───────┘   └─────────────────────────┘
    │             │
    └──────┬──────┘
           │ listens
           ▼
┌─────────────────────────────────────────────────────────┐
│              NotificationCenter                          │
│              .deviceDidShake                             │
└──────────────────────▲──────────────────────────────────┘
                       │ post
                       │
┌──────────────────────┴──────────────────────────────────┐
│          UIWindow extension                              │
│          (motionBegan override)                          │
└─────────────────────────────────────────────────────────┘
                       ▲
                       │ UIResponder chain
                       │
               [physical device shake]
```

### 3.2 데이터 흐름

**기록 흐름 (Write path):**

```
1. App code:         logger.error("Payment failed")       ──► 콘솔 (사용자 책임)
                     LogStore.shared.log(level: .error,
                       category: "Payment",
                       message: "Payment failed")          ──► 메모리
2. LogStore:         entries append (main thread dispatch)
                     @Observable가 변경 알림 발행
3. LogViewerView:    자동 re-render (열려 있을 때)
```

**조회 흐름 (Read path):**

```
[SwiftUI]
1. 사용자가 기기 흔듦
2. UIWindow.motionBegan → NotificationCenter.post(.deviceDidShake)
3. .logViewer() modifier가 notification 수신
4. Success 햅틱 발생 + sheet 표시
5. LogViewerView가 LogStore.entries를 관찰하며 리스트 렌더링

[UIKit]
1. 사용자가 기기 흔듦 (또는 LogViewer.show(from:) 호출)
2. UIWindow.motionBegan → NotificationCenter.post(.deviceDidShake)
3. LogViewer.install()이 등록한 observer가 notification 수신
4. topViewController를 찾아 UIHostingController(rootView: LogViewerView()) present
5. LogViewerView가 LogStore.entries를 관찰하며 리스트 렌더링
```

---

## 4. 모듈별 상세 설계

전체 구현은 7개 파일로 구성된다.

```
LogViewer/
├── LogEntry.swift              // 로그 1건 모델
├── LogStore.swift              // 메모리 circular buffer
├── LogViewerConfiguration.swift // 설정 객체
├── LogViewer.swift             // UIKit/SwiftUI 통합 API (install/show/configure)
├── LogViewerModifier.swift     // SwiftUI .logViewer() ViewModifier
├── ShakeGesture.swift          // UIWindow hook + Notification
└── LogViewerView.swift         // SwiftUI 뷰어 UI
```

### 4.1 LogEntry

로그 1건을 나타내는 immutable 값 타입. 모델 레이어.

**필드:**

| 필드 | 타입 | 설명 |
|---|---|---|
| `id` | `UUID` | 고유 식별자 (SwiftUI List diffing용) |
| `timestamp` | `Date` | 기록 시각 |
| `level` | `Level` | 로그 레벨 (log/notice/warning/error/critical/fault) |
| `category` | `String` | 로거 카테고리 (예: "Network", "Auth") |
| `message` | `String` | 실제 로그 메시지 |
| `file` | `String` | 호출 파일 경로 (`#file`) |
| `function` | `String` | 호출 함수 시그니처 (`#function`) |
| `line` | `Int` | 호출 라인 번호 (`#line`) |

**Level enum** (OSLog의 LogType과 1:1 매핑):

```swift
enum Level: String, CaseIterable, Equatable, Comparable {
  case log = "LOG"
  case notice = "NOTICE"
  case warning = "WARN"
  case error = "ERROR"
  case critical = "CRITICAL"
  case fault = "FAULT"

  var severity: Int {
    switch self {
    case .log: return 0
    case .notice: return 1
    case .warning: return 2
    case .error: return 3
    case .critical: return 4
    case .fault: return 5
    }
  }

  static func < (lhs: Level, rhs: Level) -> Bool {
    lhs.severity < rhs.severity
  }
}
```

**프로토콜 준수:** `Identifiable`, `Equatable`

**파생 프로퍼티:**
- `fileName: String` → `(file as NSString).lastPathComponent`
- `formatted(includeLocation:) -> String` → `"[HH:mm:ss.SSS] [LEVEL] [Category] message"` 포맷

**설계 포인트:**
- `id`가 `UUID`인 이유: `timestamp`만으로는 동시에 기록되는 로그의 중복 가능성이 있음. List diffing의 안정성을 위해 고유 id 사용.
- `Date`를 저장하고 포맷팅은 생성 시가 아니라 조회 시에 수행 — timezone 변경, locale 변경에 유연.
- `Comparable` 준수로 레벨 임계값 필터(`>= .warning`) 지원.

### 4.2 LogStore

모든 로그를 메모리에 축적하는 싱글톤 저장소. 관측 가능한 `@Observable` 클래스.

```swift
@Observable
final class LogStore {
  static let shared = LogStore()

  private(set) var entries: [LogEntry] = []
  private var maxCount: Int = 500

  private init() {}

  // 편의 API — 한 줄로 로그 기록
  func log(
    level: LogEntry.Level = .log,
    category: String = "Default",
    message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
  ) { … }

  // 직접 구성 API
  func append(_ entry: LogEntry) { … }

  func clear() { … }
  func exportAsText(includeLocation: Bool = true) -> String { … }
  func exportAsLogFile(includeLocation: Bool = true) -> URL { … }
  var availableCategories: [String] { … }
}
```

**동작 규칙:**

1. **Circular buffer**: `entries`가 `maxCount`를 초과하면 가장 오래된 것부터 제거. 기본값 500, `LogViewerConfiguration`으로 변경 가능.
2. **Main thread dispatch**: `append`는 스레드-안전하다. 호출 스레드가 main이면 즉시, 아니면 `DispatchQueue.main.async`로 dispatch. SwiftUI의 `@Observable`은 메인 스레드에서만 변경되어야 하기 때문.
3. **정렬 순서**: 오래된 순(head=old, tail=new). 뷰어는 이걸 그대로 사용하거나 역순으로 표시.
4. **`exportAsText`**: 모든 entry를 `\n`으로 join한 단일 문자열.
5. **`exportAsLogFile`**: 임시 디렉토리(`FileManager.default.temporaryDirectory`)에 `logs_YYYY-MM-DD_HH-mm-ss.log` 파일을 쓰고 URL을 반환. ShareLink에 URL을 전달하면 "파일 첨부" 형태로 공유됨.
6. **`availableCategories`**: 필터 UI용. 현재 entries에서 사용 중인 카테고리 목록을 정렬해 반환.

**설계 포인트:**

- `@Observable` 매크로는 iOS 17+에서 사용 가능. 이하에서는 `ObservableObject + @Published` 사용.
- `private init()`과 `static let shared`로 전역 싱글톤. 이유: 여러 위치에서 접근해야 하므로 DI 주입을 강제하면 오히려 불편.
- `log()` 편의 메서드는 내부에서 `LogEntry`를 생성하고 `append`를 호출. 사용자가 `LogEntry`를 직접 생성할 필요를 줄여줌.
- 로그 접근은 순전히 읽기 전용(`private(set)`). 수정은 오직 `append`/`clear`를 통해서만.

**구현 핵심 (log 편의 메서드):**

```swift
func log(
  level: LogEntry.Level = .log,
  category: String = "Default",
  message: String,
  file: String = #file,
  function: String = #function,
  line: Int = #line
) {
  guard LogViewer.isEnabled else { return }
  append(LogEntry(
    timestamp: Date(),
    level: level,
    category: category,
    message: message,
    file: file,
    function: function,
    line: line
  ))
}
```

**구현 핵심 (append):**

```swift
func append(_ entry: LogEntry) {
  if Thread.isMainThread {
    appendOnMain(entry)
  } else {
    DispatchQueue.main.async { [weak self] in
      self?.appendOnMain(entry)
    }
  }
}

private func appendOnMain(_ entry: LogEntry) {
  entries.append(entry)
  if entries.count > maxCount {
    entries.removeFirst(entries.count - maxCount)
  }
}
```

**구현 핵심 (exportAsLogFile):**

```swift
func exportAsLogFile(includeLocation: Bool = true) -> URL {
  let text = exportAsText(includeLocation: includeLocation)
  let timestamp = Self.fileNameFormatter.string(from: Date())
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("logs_\(timestamp).log")
  try? text.write(to: url, atomically: true, encoding: .utf8)
  return url
}
```

### 4.3 LogViewerConfiguration

라이브러리 동작을 커스터마이징하는 설정 객체.

```swift
public struct LogViewerConfiguration {
  /// 최대 보관 로그 수 (기본: 500)
  public var maxLogCount: Int = 500

  /// 트리거 방식 (기본: .shake)
  public var trigger: Trigger = .shake

  /// 타임스탬프 표시 포맷 (기본: "HH:mm:ss.SSS")
  public var dateFormat: String = "HH:mm:ss.SSS"

  public enum Trigger {
    case shake              // 기기 흔들기
    case tripleFingerTap    // 3-finger tap
    case manual             // 자동 트리거 없음, LogViewer.show()로만 접근
  }
}
```

**설정 적용:**

```swift
LogViewer.configure { config in
  config.maxLogCount = 1000
  config.trigger = .shake
  config.dateFormat = "HH:mm:ss"
}
```

`configure`는 앱 시작 시 1회 호출. `LogStore.maxCount`와 shake/tap 감지 활성화 여부에 반영된다.

### 4.4 LogViewer (통합 API)

SwiftUI와 UIKit 양쪽에서 사용할 수 있는 진입점. `enum`으로 선언하여 인스턴스화를 방지한다.

```swift
public enum LogViewer {

  // MARK: - 활성화 제어

  /// 런타임 활성화 제어. 기본값은 DEBUG 빌드에서만 true.
  /// 모든 public 함수(install, show, log 등)는 이 값이 false이면 no-op.
  public static var isEnabled: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }()

  // MARK: - Configuration

  /// 라이브러리 설정. 앱 시작 시 1회 호출.
  public static func configure(
    _ block: (inout LogViewerConfiguration) -> Void
  ) { … }

  // MARK: - UIKit

  /// UIKit 앱에서 shake 시 자동 트리거 활성화.
  /// AppDelegate.didFinishLaunchingWithOptions에서 호출.
  public static func install() { … }

  /// UIKit에서 수동으로 로그 뷰어 표시.
  public static func show(from viewController: UIViewController) { … }

  /// 현재 최상위 ViewController를 찾아 로그 뷰어 표시.
  /// install() 없이도 독립적으로 사용 가능.
  public static func show() { … }
}
```

**isEnabled 동작 원리:**

SPM 패키지는 앱과 동일한 build configuration으로 빌드된다. 앱이 Release로 빌드되면 라이브러리도 Release로 빌드되므로, **라이브러리 내부의 `#if DEBUG`는 앱의 빌드 설정을 따른다.** 따라서 기본값만으로 대부분의 프로젝트에서 별도 설정 없이 Release에서 자동 비활성화된다.

커스텀 플래그를 사용하는 프로젝트에서는 런타임에 직접 제어할 수 있다:

```swift
// 예: DEV 플래그를 사용하는 프로젝트
#if DEV
LogViewer.isEnabled = true
#endif
```

모든 public 진입점에서 `isEnabled`를 체크하므로, false일 때는 로그 기록·뷰어 표시·shake 감지 등 모든 동작이 no-op이 된다.

**UIKit install() 구현:**

```swift
public static func install() {
  guard isEnabled else { return }
  NotificationCenter.default.addObserver(
    forName: .deviceDidShake,
    object: nil,
    queue: .main
  ) { _ in
    guard isEnabled else { return }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    guard let topVC = Self.topViewController() else { return }
    // 이미 LogViewer가 표시 중이면 무시
    guard !(topVC is UIHostingController<LogViewerView>) else { return }
    let hostingVC = UIHostingController(rootView: LogViewerView())
    hostingVC.modalPresentationStyle = .pageSheet
    topVC.present(hostingVC, animated: true)
  }
}
```

**topViewController 탐색:**

```swift
private static func topViewController(
  from root: UIViewController? = nil
) -> UIViewController? {
  let root = root ?? UIApplication.shared.connectedScenes
    .compactMap { $0 as? UIWindowScene }
    .flatMap { $0.windows }
    .first { $0.isKeyWindow }?
    .rootViewController

  if let nav = root as? UINavigationController {
    return topViewController(from: nav.visibleViewController)
  }
  if let tab = root as? UITabBarController,
     let selected = tab.selectedViewController {
    return topViewController(from: selected)
  }
  if let presented = root?.presentedViewController {
    return topViewController(from: presented)
  }
  return root
}
```

**show(from:) 구현:**

```swift
public static func show(from viewController: UIViewController) {
  guard isEnabled else { return }
  let hostingVC = UIHostingController(rootView: LogViewerView())
  hostingVC.modalPresentationStyle = .pageSheet
  viewController.present(hostingVC, animated: true)
}
```

**show() 구현 (programmatic trigger):**

```swift
public static func show() {
  guard isEnabled else { return }
  guard let topVC = topViewController() else { return }
  show(from: topVC)
}
```

### 4.5 LogViewerModifier (SwiftUI)

SwiftUI 앱에서 한 줄로 LogViewer를 연결하는 ViewModifier.

```swift
private struct LogViewerModifier: ViewModifier {
  @State private var isPresented: Bool = false

  func body(content: Content) -> some View {
    content
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        guard LogViewer.isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isPresented = true
      }
      .sheet(isPresented: $isPresented) {
        LogViewerView()
      }
  }
}

public extension View {
  /// LogViewer를 연결한다. Shake 제스처로 뷰어가 표시된다.
  func logViewer() -> some View {
    modifier(LogViewerModifier())
  }
}
```

**사용법:**

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .logViewer()  // isEnabled가 false이면 내부적으로 no-op
    }
  }
}
```

**기존 `.onShake(perform:)` 확장도 유지** — 사용자가 shake에 커스텀 동작을 연결하고 싶을 때:

```swift
public extension View {
  func onShake(perform action: @escaping () -> Void) -> some View {
    modifier(ShakeGestureModifier(action: action))
  }
}
```

### 4.6 ShakeGesture

물리적 기기 흔들기를 감지하여 NotificationCenter로 전달하는 브리지.

**구성:**

1. **UIWindow extension** — motion 이벤트 후킹
2. **Notification.Name 확장** — 브로드캐스트 채널 정의

#### 4.6.1 UIWindow 후킹

iOS는 `UIResponder.motionBegan(_:with:)`과 `motionEnded(_:with:)` 메서드로 모션 이벤트를 보낸다. `UIWindow`는 responder chain의 최상위이므로 여기서 오버라이드하면 앱 전역 shake를 감지할 수 있다.

```swift
extension UIWindow {
  open override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
    super.motionBegan(motion, with: event)
    if motion == .motionShake {
      NotificationCenter.default.post(name: .deviceDidShake, object: event)
    }
  }
}
```

**왜 `motionBegan`인가?**
- `motionBegan`: 흔들기가 **감지되자마자** 호출 → 사용자가 흔드는 도중 즉시 반응
- `motionEnded`: 흔들기가 **끝난 후** 호출 → "흔들고 멈춰야 반응"하는 느낌

즉각적인 UX를 위해 `motionBegan` 선택.

**중요 주의:**
- Swift extension에서 일반 메서드를 `override`할 수 없지만, `UIResponder`의 motion 메서드는 Objective-C 기반이라 예외적으로 허용됨.
- `super`를 반드시 호출해야 한다 (responder chain 보존).
- 여러 UIWindow가 있는 앱(예: 외부 디스플레이, 분리된 장면)에서도 모든 window에 대해 동일하게 동작.

#### 4.6.2 Notification 채널

```swift
extension Notification.Name {
  static let deviceDidShake = Notification.Name("LogViewer.deviceDidShake")
}
```

라이브러리 고유 prefix를 사용하여 충돌을 방지한다.

### 4.7 LogViewerView

로그를 조회하는 SwiftUI 뷰어. 핵심 UI.

**상태(State):**

```swift
struct LogViewerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var store = LogStore.shared  // @Observable observation

  // 필터
  @State private var searchText: String = ""
  @State private var minimumLevel: LogEntry.Level? = nil    // 임계값 필터
  @State private var selectedCategory: String? = nil
  @State private var showLocation: Bool = false

  // 검색 네비게이션
  @State private var matches: [MatchLocation] = []
  @State private var currentMatchIndex: Int = 0

  // 검색 debounce
  @State private var searchTask: Task<Void, Never>?

  // 초기 스크롤 1회성 플래그
  @State private var didInitialScroll: Bool = false
}
```

**레이아웃 구조 (위에서 아래):**

```
NavigationStack
└── VStack(spacing: 0)
    ├── filterBar                 (Level threshold/Category/위치 토글 chip)
    ├── searchNavigationBar       (검색 중일 때만: "3/15" + ↑↓ 버튼)
    ├── emptyState | logList      (조건부)
└── .searchable(text: $searchText)
└── .navigationTitle("Debug Logs (\(entries.count))")
└── .toolbar { 닫기 | 메뉴 }
└── .onChange(of: searchText) { debounceRecalculate() }
└── .onChange(of: minimumLevel / selectedCategory / store.entries) { recalculateMatches() }
```

**필터 적용 순서:**

```swift
private var filteredEntries: [LogEntry] {
  store.entries.filter { entry in
    if let minimumLevel, entry.level < minimumLevel { return false }
    if let selectedCategory, entry.category != selectedCategory { return false }
    return true
  }
}
```

레벨 필터는 단일 선택이 아니라 **임계값**이다. `.warning`을 선택하면 warning, error, critical, fault가 모두 표시된다. `Level`이 `Comparable`을 준수하므로 `<` 비교만으로 구현 가능.

`searchText`는 필터가 아니라 **하이라이트와 네비게이션**에만 사용된다. 즉 검색어 입력 중에도 전체 로그가 리스트에 그대로 표시되고, 일치 위치가 하이라이트된다.

**로그 리스트 렌더링:**

```swift
ScrollViewReader { proxy in
  List(filteredEntries) { entry in
    LogEntryRow(
      entry: entry,
      searchText: searchText,
      currentMatch: currentMatchForEntry(entry),
      showLocation: showLocation
    )
    .id(entry.id)
    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
    .onTapGesture { selectedEntry = entry }           // 탭 → 상세 뷰
    .contextMenu { copyButton(for: entry) }           // 길게 누르기 → 복사
  }
  .listStyle(.plain)
  .onAppear { /* 초기 스크롤 */ }
  .onChange(of: matches) { /* 첫 매치로 스크롤 */ }
  .onChange(of: currentMatchIndex) { /* 현재 매치로 스크롤 */ }
}
.sheet(item: $selectedEntry) { entry in
  LogEntryDetailView(entry: entry)                    // 상세 뷰
}
```

**LogEntryRow 구조:**

```swift
VStack(alignment: .leading, spacing: 4) {
  HStack {
    LevelBadge(level: entry.level)      // 색상 배경의 캡슐 라벨
    CategoryLabel(text: entry.category)
    Spacer()
    TimeLabel(date: entry.timestamp)     // HH:mm:ss.SSS
  }

  Text(highlightedMessage)               // AttributedString, monospaced
    .textSelection(.enabled)

  if showLocation {
    LocationLabel(text: "↳ \(fileName):\(line) \(function)")
  }
}
```

**LogEntryDetailView (탭 시 상세):**

```swift
struct LogEntryDetailView: View {
  let entry: LogEntry

  var body: some View {
    NavigationStack {
      List {
        Section("메시지") { Text(entry.message).textSelection(.enabled) }
        Section("메타") {
          LabeledContent("Level", value: entry.level.rawValue)
          LabeledContent("Category", value: entry.category)
          LabeledContent("Time", value: entry.timestamp.formatted())
        }
        Section("위치") {
          LabeledContent("File", value: entry.fileName)
          LabeledContent("Function", value: entry.function)
          LabeledContent("Line", value: "\(entry.line)")
        }
      }
      .toolbar {
        Button("복사") { copyToClipboard(entry) }
      }
    }
  }
}
```

**LogEntryRow의 하이라이트 로직**은 별도 섹션에서 설명(§5.4).

**툴바 메뉴:**

```swift
Menu {
  Menu {
    ShareLink(item: store.exportAsText(...)) { Label("텍스트로 공유", …) }
    ShareLink(item: store.exportAsLogFile(...)) { Label(".log 파일로 공유", …) }
  } label: {
    Label("전체 공유", systemImage: "square.and.arrow.up")
  }

  Button(role: .destructive) { store.clear() } label: {
    Label("초기화", systemImage: "trash")
  }
} label: {
  Image(systemName: "ellipsis.circle")
}
```

Menu → Menu 중첩 구조로 "전체 공유"를 서브메뉴화. iOS 15+ 지원.

---

## 5. 핵심 기능 상세

### 5.1 환경 구분 (이중 안전장치)

**목표:** 프로덕션 빌드에서 LogViewer가 동작하지 않아야 한다.

**전략:** 라이브러리 내부에 `isEnabled` 런타임 플래그를 두고, 기본값을 `#if DEBUG`로 결정한다. 모든 public 진입점에서 이 값을 체크하여, false이면 no-op으로 동작한다. 이를 통해 프로젝트의 compile flag 네이밍에 관계없이 유연하게 제어할 수 있다.

```swift
public static var isEnabled: Bool = {
  #if DEBUG
  return true
  #else
  return false
  #endif
}()
```

**3가지 시나리오별 적용:**

#### 시나리오 1: 일반 프로젝트 (DEBUG 플래그 사용)

별도 설정 불필요. Release 빌드에서 `isEnabled`가 자동으로 `false`가 되어 모든 동작이 no-op.

```swift
// 그냥 쓰면 된다 — #if DEBUG 가드 불필요
LogViewer.install()
LogStore.shared.log(level: .error, category: "App", message: "hello")
```

#### 시나리오 2: 커스텀 플래그 프로젝트 (DEV, STAGING 등)

앱 시작 시 런타임에 직접 활성화:

```swift
// AppDelegate 또는 앱 시작 시점에서 1줄
#if DEV
LogViewer.isEnabled = true
#endif
```

이렇게 하면 DEV 빌드에서만 활성화되고, Staging/Release에서는 비활성화 상태가 유지된다.

#### 시나리오 3: 바이너리에서 완전 제거

코드가 바이너리에 포함되는 것 자체를 원하지 않는 경우, 조건부 import를 사용:

```swift
#if DEBUG  // 또는 #if DEV
import LogViewer
#endif
```

이 경우 Release 빌드에서는 symbol 자체가 링크되지 않아 바이너리 크기 영향 0. 단, 모든 호출부를 `#if` 가드로 감싸야 한다.

**isEnabled가 false일 때 영향받는 동작:**

| API | 동작 |
|---|---|
| `LogStore.shared.log(...)` | 즉시 return, 메모리에 기록하지 않음 |
| `LogViewer.install()` | shake observer를 등록하지 않음 |
| `LogViewer.show()` / `show(from:)` | 뷰어를 표시하지 않음 |
| `.logViewer()` modifier | shake 이벤트 수신해도 무시 |

**요약:**

| 방식 | 대상 | 바이너리 포함 | 사용자 작업 |
|---|---|---|---|
| **기본값 (자동)** | `DEBUG` 플래그 사용 프로젝트 | 포함 (no-op) | 없음 |
| **`isEnabled` 런타임 제어** | 커스텀 플래그 프로젝트 (DEV 등) | 포함 (no-op) | 앱 시작 시 1줄 |
| **조건부 import** | 바이너리 완전 제거 원하는 경우 | 미포함 | 모든 호출부 `#if` 가드 |

### 5.2 스레드 안전성

로그는 어느 스레드에서든 발생할 수 있다 (네트워크 완료 콜백, 백그라운드 처리 등). 그러나 `@Observable` 변경은 **반드시 main thread**에서 일어나야 SwiftUI가 안전하게 갱신된다.

**해결:** `LogStore.append`가 스레드를 검사하고 필요시 dispatch한다.

```swift
func append(_ entry: LogEntry) {
  if Thread.isMainThread {
    appendOnMain(entry)
  } else {
    DispatchQueue.main.async { [weak self] in
      self?.appendOnMain(entry)
    }
  }
}
```

**왜 DispatchQueue.main.async인가?**
- `DispatchQueue.main.sync`는 현재 스레드가 main일 때 데드락. 항상 async 안전.
- 메인이 이미 main이면 `Thread.isMainThread` 체크로 dispatch를 건너뛰어 지연 없이 즉시 실행.

**대안: Swift Concurrency(@MainActor)**
```swift
@MainActor
final class LogStore { … }
```
이 경우 `append` 호출부에서 `await`가 필요해지므로 기존 logger 코드를 모두 async로 변경해야 함. 현실적 비용이 커서 현재는 GCD 방식 선택.

### 5.3 메모리 관리 (Circular Buffer)

**전략:** 최근 N건만 유지 (기본 500). 초과분은 가장 오래된 것부터 폐기. `LogViewerConfiguration.maxLogCount`로 변경 가능.

```swift
entries.append(entry)
if entries.count > maxCount {
  entries.removeFirst(entries.count - maxCount)
}
```

**500개가 적절한 이유:**
- 한 로그 평균 200byte 가정 시 500개 = 약 100KB. 부담 없음.
- UX상 스크롤로 충분히 탐색 가능한 양.
- QA 세션 동안 발생하는 의미있는 로그를 대부분 포함.

**대안:**
- `Deque`(Swift Collections) 사용 시 `removeFirst`가 O(1). Array는 O(n)이지만 500개 수준에서는 체감 차이 없음.

### 5.4 검색 하이라이팅

목표: 사용자가 `searchable`에 입력한 검색어가 각 로그의 `message` 내에서 일치하는 모든 범위를 배경색으로 강조한다. "현재 선택된 일치"는 별도 색상으로 더 강하게 표시한다.

**기술:** `AttributedString`의 속성 subscript 활용.

```swift
private var highlightedMessage: AttributedString {
  var attributed = AttributedString(entry.message)
  guard !searchText.isEmpty else { return attributed }

  let message = entry.message
  var searchStart = message.startIndex
  while searchStart < message.endIndex,
        let range = message.range(
          of: searchText,
          options: .caseInsensitive,
          range: searchStart..<message.endIndex
        ) {
    let charStart = message.distance(from: message.startIndex, to: range.lowerBound)
    let charLength = message.distance(from: range.lowerBound, to: range.upperBound)

    // String.Index → AttributedString.Index 변환
    let attrLower = attributed.index(attributed.startIndex, offsetByCharacters: charStart)
    let attrUpper = attributed.index(attrLower, offsetByCharacters: charLength)
    let attrRange = attrLower..<attrUpper

    let isCurrent = (currentMatch?.lowerBound == charStart
                     && currentMatch?.upperBound == charStart + charLength)
    attributed[attrRange].backgroundColor = isCurrent ? .yellow : .gray
    attributed[attrRange].foregroundColor = .black

    searchStart = range.upperBound
  }
  return attributed
}
```

**핵심 포인트:**

1. **String.Index vs AttributedString.Index**: 둘은 호환되지 않음. `message.distance(from:to:)`로 character offset을 구한 뒤 `attributed.index(_:offsetByCharacters:)`로 변환.
2. **대소문자 무시**: `options: .caseInsensitive`로 검색 유연성 확보.
3. **"현재 일치" 판별**: `MatchLocation` 구조체로 entryId와 offset을 묶어 전달. `lowerBound + upperBound`가 모두 일치해야 현재로 판정.
4. **색상 선택**:
   - 일반 일치: 회색 배경 (은은한 표시)
   - 현재 선택: 노란 배경 (뚜렷한 강조)

**Text가 AttributedString을 렌더링할 때 주의사항:**
- SwiftUI `Text`는 `AttributedString`의 SwiftUI attribute(foregroundColor, backgroundColor, underlineStyle, font 등)를 지원.
- `.font(.system(.footnote, design: .monospaced))`는 Text의 외부 modifier로 적용하므로 AttributedString 내부 font와 충돌하지 않음.

### 5.5 검색 Debounce

빠른 타이핑 시 매 키 입력마다 `recalculateMatches()`가 호출되면 불필요한 연산이 반복된다. 200ms debounce를 적용한다.

```swift
private func debounceRecalculate() {
  searchTask?.cancel()
  searchTask = Task {
    try? await Task.sleep(for: .milliseconds(200))
    guard !Task.isCancelled else { return }
    recalculateMatches()
  }
}
```

**적용 범위:**
- `searchText` 변경 → debounce 적용 (`debounceRecalculate()`)
- `minimumLevel`, `selectedCategory`, `store.entries` 변경 → 즉시 재계산 (`recalculateMatches()`)

검색어 외 필터 변경은 사용자가 명시적으로 선택하는 동작이므로 즉시 반영이 자연스럽다.

### 5.6 레벨 임계값 필터

기존 설계의 단일 레벨 선택 대신, **임계값 기반 필터**를 사용한다.

**UI:**

```
[전체] [LOG+] [NOTICE+] [WARN+] [ERROR+] [CRITICAL+] [FAULT]
```

선택된 칩의 의미: "해당 레벨 이상의 로그만 표시"

**구현:**

```swift
// Level이 Comparable을 준수하므로 단순 비교
private var filteredEntries: [LogEntry] {
  store.entries.filter { entry in
    if let minimumLevel, entry.level < minimumLevel { return false }
    if let selectedCategory, entry.category != selectedCategory { return false }
    return true
  }
}
```

`nil`은 "전체"를 의미한다.

### 5.7 순환 검색 네비게이션

**목표:** Xcode 콘솔의 `⌘G` / `⌘⇧G`처럼, 일치 위치를 반복 순회할 수 있어야 한다. 양 끝에 도달하면 순환.

**데이터 구조:**

```swift
private struct MatchLocation: Equatable {
  let entryId: UUID
  let lowerBound: Int  // character offset
  let upperBound: Int
}
```

`[MatchLocation]`을 전체 검색 결과로 유지하고, `currentMatchIndex: Int`로 현재 위치를 추적.

**재계산 트리거:**

```swift
.onChange(of: searchText)       { _, _ in debounceRecalculate() }
.onChange(of: minimumLevel)     { _, _ in recalculateMatches() }
.onChange(of: selectedCategory) { _, _ in recalculateMatches() }
.onChange(of: store.entries)    { _, _ in recalculateMatches() }
```

- 검색어 변경 → debounce 후 재계산.
- 필터, 저장소 변경 → 즉시 재계산.
- `currentMatchIndex`는 0으로 리셋.

**재계산 로직:**

```swift
private func recalculateMatches() {
  currentMatchIndex = 0
  guard !searchText.isEmpty else {
    matches = []
    return
  }
  var result: [MatchLocation] = []
  for entry in filteredEntries {
    let message = entry.message
    var searchStart = message.startIndex
    while searchStart < message.endIndex,
          let range = message.range(
            of: searchText,
            options: .caseInsensitive,
            range: searchStart..<message.endIndex
          ) {
      result.append(MatchLocation(
        entryId: entry.id,
        lowerBound: message.distance(from: message.startIndex, to: range.lowerBound),
        upperBound: message.distance(from: message.startIndex, to: range.upperBound)
      ))
      searchStart = range.upperBound
    }
  }
  matches = result
}
```

**순환 네비게이션:**

```swift
private func goToPreviousMatch() {
  guard !matches.isEmpty else { return }
  currentMatchIndex = (currentMatchIndex <= 0)
    ? matches.count - 1
    : currentMatchIndex - 1
}

private func goToNextMatch() {
  guard !matches.isEmpty else { return }
  currentMatchIndex = (currentMatchIndex >= matches.count - 1)
    ? 0
    : currentMatchIndex + 1
}
```

**버튼 비활성 조건:** `matches.isEmpty`일 때만. 일치가 1개 이상이면 양방향 버튼 모두 항상 활성 (순환 가능하므로).

**UI 표시:** `"\(currentMatchIndex + 1) / \(matches.count)"` 형식으로 카운트.

### 5.8 단건 로그 액션

각 로그 행에서 개별 로그를 조작할 수 있다.

| 제스처 | 동작 | 구현 |
|---|---|---|
| **탭** | 상세 뷰 표시 (전체 메시지 + file:line:function) | `.onTapGesture` → `.sheet(item:)` |
| **길게 누르기** | 해당 로그 1건 포맷팅 후 클립보드 복사 | `.contextMenu` → `UIPasteboard` |

**복사 포맷:**

```
[2026-04-09 14:23:45.123] [ERROR] [Payment] Payment failed: insufficient balance
↳ PaymentService.swift:42 processPayment()
```

### 5.9 공유 (Text vs .log file)

두 가지 방식을 서브메뉴로 제공.

| 방식 | ShareLink item | UX |
|---|---|---|
| **텍스트로 공유** | `String` | Share Sheet에서 "텍스트"로 인식. 일부 앱은 본문에 직접 삽입. |
| **.log 파일로 공유** | `URL` (임시 파일) | Share Sheet에서 "첨부 파일"로 인식. Slack 파일 업로드, Mail attachment로 일관되게 처리. |

**ShareLink item 타입이 UX를 결정한다:**

```swift
// 텍스트 방식
ShareLink(item: store.exportAsText(includeLocation: showLocation)) {
  Label("텍스트로 공유", systemImage: "doc.text")
}

// 파일 방식
ShareLink(item: store.exportAsLogFile(includeLocation: showLocation)) {
  Label(".log 파일로 공유", systemImage: "doc")
}
```

**.log 확장자의 이점:**
- VS Code, JetBrains IDE 등에서 자동 syntax highlighting 제공
- "로그 파일"이라는 의미가 확장자만으로 전달됨
- 기능적으로는 `.txt`와 동일하지만 관례·도구 지원 측면에서 유리

**임시 파일 위치:**
- `FileManager.default.temporaryDirectory` — iOS가 필요시 자동 정리. 수동 삭제 불필요.
- 파일명에 타임스탬프 포함 → 여러 공유 간 구분 용이.

### 5.10 자동 스크롤

**세 가지 스크롤 상황과 각 해결책:**

#### (1) 시트 오픈 시 → 최신 로그(맨 아래)로 스크롤

```swift
@State private var didInitialScroll: Bool = false

.onAppear {
  guard !didInitialScroll else { return }
  didInitialScroll = true
  DispatchQueue.main.async {
    if let lastId = filteredEntries.last?.id {
      proxy.scrollTo(lastId, anchor: .bottom)
    }
  }
}
```

**Why async?** `onAppear` 시점에 List는 아직 렌더링 완료 전일 수 있다. 다음 runloop로 지연시켜야 `scrollTo`가 정확히 동작한다.

**Why `didInitialScroll`?** 이후 필터 변경 등으로 `onAppear`가 다시 호출되어도 초기 스크롤이 반복되지 않도록 1회성 플래그.

#### (2) 검색 결과 갱신 시 → 첫 일치로 스크롤

```swift
.onChange(of: matches) { _, newMatches in
  guard let first = newMatches.first else { return }
  withAnimation {
    proxy.scrollTo(first.entryId, anchor: .center)
  }
}
```

#### (3) ↑/↓ 버튼 클릭 시 → 현재 일치로 스크롤

```swift
.onChange(of: currentMatchIndex) { _, newIndex in
  guard matches.indices.contains(newIndex) else { return }
  withAnimation {
    proxy.scrollTo(matches[newIndex].entryId, anchor: .center)
  }
}
```

**중요: 각 Row에 `.id(entry.id)` 필수** — ScrollViewReader의 `scrollTo`가 ID로 대상을 식별.

### 5.11 햅틱 피드백

Shake 감지 직후 `UINotificationFeedbackGenerator().notificationOccurred(.success)`를 발생시킨다. 2단 진동으로 "감지됨 + 반응됨" 느낌을 전달한다.

**대안 스타일:**
| 클래스 | 스타일 | 느낌 |
|---|---|---|
| `UIImpactFeedbackGenerator` | `.light` | 가벼운 탭 |
| `UIImpactFeedbackGenerator` | `.medium` | 적당한 탭 |
| `UIImpactFeedbackGenerator` | `.heavy` | 묵직한 탭 |
| `UIImpactFeedbackGenerator` | `.rigid` | 날카로운 클릭 |
| `UIImpactFeedbackGenerator` | `.soft` | 부드러운 탭 |
| `UINotificationFeedbackGenerator` | `.success` | 성공 알림 (2단) |
| `UINotificationFeedbackGenerator` | `.warning` | 경고 알림 (2단) |
| `UINotificationFeedbackGenerator` | `.error` | 에러 알림 (강한 3단) |
| `UISelectionFeedbackGenerator` | - | 선택 변경 |

**시뮬레이터 주의:** 햅틱은 실기기에서만 체감 가능. 시뮬레이터는 호출이 silent하게 실패.

---

## 6. 사용법

### 6.1 로그 기록 (백엔드 무관)

LogStore는 콘솔 출력에 관여하지 않는다. 사용자가 어떤 방식으로 콘솔에 출력하든, `LogStore.shared.log()`만 추가하면 뷰어에 기록된다.

```
사용자의 로거 ──┬──→ 콘솔 출력 (print / os.Logger / swift-log)  ← 사용자 책임
               │
               └──→ LogStore.shared.log(...)                    ← 라이브러리 책임
                         │
                         └──→ LogViewerView에 표시
```

**예시 1: print 사용자**

```swift
final class MyLogger {
  func error(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    print("❌ [\(Date())] \(msg)")

    // isEnabled가 false이면 내부적으로 no-op — #if DEBUG 가드 불필요
    LogStore.shared.log(level: .error, category: "App", message: msg,
                        file: file, function: function, line: line)
  }
}
```

**예시 2: os.Logger 사용자**

```swift
final class MyLogger {
  private let osLogger = os.Logger(subsystem: "com.example.app", category: "Network")

  func error(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    osLogger.error("\(msg, privacy: .public)")

    // isEnabled가 false이면 내부적으로 no-op — #if DEBUG 가드 불필요
    LogStore.shared.log(level: .error, category: "Network", message: msg,
                        file: file, function: function, line: line)
  }
}
```

**예시 3: swift-log 사용자**

```swift
import Logging

var logger = Logger(label: "com.example.app")

func doSomething() {
  logger.info("Starting operation")

  // isEnabled가 false이면 내부적으로 no-op — #if DEBUG 가드 불필요
  LogStore.shared.log(level: .notice, category: "App", message: "Starting operation")
}
```

### 6.2 SwiftUI 앱에 연결

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .logViewer()  // shake + sheet + 상태 관리 모두 내장
                      // isEnabled가 false이면 내부적으로 no-op
    }
  }
}
```

한 줄이면 완료. Shake 제스처 감지, 햅틱 피드백, sheet 표시가 모두 포함된다. Release 빌드에서는 `isEnabled`가 false이므로 자동으로 비활성화된다.

**커스텀 동작이 필요한 경우** `.onShake(perform:)`을 직접 사용:

```swift
ContentView()
  .onShake {
    // 커스텀 로직 (예: 특정 조건에서만 뷰어 표시)
    if isDebugMode { showLogViewer = true }
  }
  .sheet(isPresented: $showLogViewer) { LogViewerView() }
```

### 6.3 UIKit 앱에 연결

**자동 트리거 (shake):**

```swift
// AppDelegate.swift
func application(_ app: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
  LogViewer.install()  // shake 감지 활성화. Release에서는 isEnabled가 false이므로 no-op.
  return true
}
```

**수동 트리거 (버튼 등):**

```swift
// 디버그 설정 화면의 버튼
@IBAction func showLogsTapped() {
  LogViewer.show(from: self)  // isEnabled가 false이면 no-op
}

// 또는 현재 최상위 VC를 자동으로 찾아 표시
LogViewer.show()
```

### 6.4 Configuration (선택)

```swift
LogViewer.configure { config in
  config.maxLogCount = 1000
  config.trigger = .shake
  config.dateFormat = "HH:mm:ss"
}
```

앱 시작 시 1회 호출. 호출하지 않으면 기본값이 사용된다. Release 빌드에서는 `isEnabled`가 false이므로 configure를 호출해도 실질적 영향 없음.

**커스텀 플래그 프로젝트에서의 활성화:**

```swift
// DEV 플래그를 사용하는 프로젝트
#if DEV
LogViewer.isEnabled = true
#endif

// 이후 별도 가드 없이 사용
LogViewer.install()
LogStore.shared.log(level: .info, category: "App", message: "hello")
```

### 6.5 로그 확인 (QA)

1. 앱 사용 중 기기를 흔들기 (또는 개발자가 제공한 디버그 버튼 탭)
2. 성공 햅틱 + LogViewer sheet 등장
3. 최신 로그가 하단에 위치, 위로 스와이프하면 과거 로그
4. 필요 시 Level 임계값/Category 필터 적용, 검색으로 특정 메시지 찾기
5. 로그 탭 → 상세 정보 확인 (file, function, line)
6. 로그 길게 누르기 → 1건 복사
7. 우상단 ⋯ → 전체 공유 → 텍스트/로그 파일로 내보내기

---

## 7. SPM 패키지화 가이드

### 7.1 패키지 레이아웃 제안

```
LogViewer/
├── Package.swift
├── README.md
├── LICENSE
├── Sources/
│   └── LogViewer/
│       ├── Models/
│       │   ├── LogEntry.swift
│       │   └── MatchLocation.swift
│       ├── Store/
│       │   └── LogStore.swift
│       ├── Configuration/
│       │   └── LogViewerConfiguration.swift
│       ├── Core/
│       │   ├── LogViewer.swift           // UIKit/SwiftUI 통합 API
│       │   └── ShakeGesture.swift
│       └── Views/
│           ├── LogViewerView.swift
│           ├── LogViewerModifier.swift   // .logViewer()
│           ├── LogEntryRow.swift
│           └── LogEntryDetailView.swift
├── Tests/
│   └── LogViewerTests/
│       ├── LogStoreTests.swift
│       └── HighlightingTests.swift
└── Examples/
    ├── SwiftUIExample/                   // SwiftUI 샘플 앱
    │   ├── SwiftUIExampleApp.swift
    │   ├── ContentView.swift
    │   └── AppLogger.swift
    └── UIKitExample/                     // UIKit 샘플 앱
        ├── AppDelegate.swift
        ├── SceneDelegate.swift
        ├── ViewController.swift
        └── AppLogger.swift
```

### 7.2 Package.swift 예시

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LogViewer",
  platforms: [.iOS(.v16)],
  products: [
    .library(name: "LogViewer", targets: ["LogViewer"]),
  ],
  targets: [
    .target(
      name: "LogViewer",
      dependencies: [],
      swiftSettings: [
        .define("DEBUG", .when(configuration: .debug))
      ]
    ),
    .testTarget(
      name: "LogViewerTests",
      dependencies: ["LogViewer"]
    ),
  ]
)
```

### 7.3 Public API 설계

**공개해야 할 것:**

```swift
// 모델
public struct LogEntry: Identifiable, Equatable {
  public enum Level: String, CaseIterable, Equatable, Comparable { … }
  public let id: UUID
  public let timestamp: Date
  public let level: Level
  public let category: String
  public let message: String
  public let file: String
  public let function: String
  public let line: Int
}

// 설정
public struct LogViewerConfiguration {
  public var maxLogCount: Int
  public var trigger: Trigger
  public var dateFormat: String
  public enum Trigger { case shake, tripleFingerTap, manual }
}

// 저장소 (싱글톤)
public final class LogStore {
  public static let shared: LogStore
  public private(set) var entries: [LogEntry]
  public func log(level:category:message:file:function:line:)
  public func append(_ entry: LogEntry)
  public func clear()
  public func exportAsText(includeLocation: Bool) -> String
  public func exportAsLogFile(includeLocation: Bool) -> URL
}

// 통합 API
public enum LogViewer {
  public static var isEnabled: Bool                                // 런타임 활성화 제어 (기본: DEBUG에서만 true)
  public static func configure(_ block: (inout LogViewerConfiguration) -> Void)
  public static func install()                                    // UIKit 자동 트리거
  public static func show(from viewController: UIViewController)  // UIKit 수동
  public static func show()                                       // programmatic
}

// SwiftUI View modifier
public extension View {
  func logViewer() -> some View
  func onShake(perform: @escaping () -> Void) -> some View
}

// 뷰
public struct LogViewerView: View {
  public init()
  public var body: some View
}
```

**비공개로 두어야 할 것:**
- `MatchLocation` (내부 전용)
- `ShakeGestureModifier` (View 확장으로만 노출)
- `LogViewerModifier` (`.logViewer()`로만 노출)
- `UIWindow.motionBegan` extension (라이브러리 로드 시 자동 적용)
- `topViewController()` (내부 유틸리티)
- `LogEntryDetailView` (내부 UI 컴포넌트)

### 7.4 라이브러리 사용자용 통합 예시

```swift
import LogViewer

// 1. (선택) Configuration
LogViewer.configure { config in
  config.maxLogCount = 1000
}

// 2-A. SwiftUI 앱
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .logViewer()
    }
  }
}

// 2-B. UIKit 앱
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ app: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    LogViewer.install()
    return true
  }
}

// 3. 기존 로거에 LogStore hook (어떤 로거든 동일한 패턴)
final class AppLogger {
  func error(_ msg: String, file: String = #file, function: String = #function, line: Int = #line) {
    print("❌ \(msg)")  // 콘솔 출력 — 사용자 방식 그대로
    LogStore.shared.log(level: .error, category: "App", message: msg,
                        file: file, function: function, line: line)
  }
}
```

### 7.5 프로덕션 제어 전략

라이브러리 내부에 `isEnabled` 런타임 플래그가 있으며, 기본값이 `#if DEBUG`로 결정된다. 따라서 **대부분의 프로젝트에서는 별도 설정 없이 Release에서 자동 비활성화**된다.

**권장 방식 (기본값 사용):**

```swift
import LogViewer  // 항상 import — #if DEBUG 가드 불필요

LogViewer.install()                      // Release에서는 no-op
LogStore.shared.log(message: "hello")    // Release에서는 no-op
```

**커스텀 플래그 프로젝트 (DEV, STAGING 등):**

```swift
import LogViewer

#if DEV
LogViewer.isEnabled = true  // DEV 빌드에서만 활성화
#endif
```

**바이너리 완전 제거가 필요한 경우:**

```swift
#if DEBUG
import LogViewer
#endif
```

이 경우 Release 빌드에서 symbol 자체가 링크되지 않아 바이너리 크기 영향 0. 단, 모든 호출부를 `#if` 가드로 감싸야 한다.

자세한 시나리오별 설명은 §5.1 참조.

### 7.6 샘플 프로젝트

`Examples/` 디렉토리에 SwiftUI와 UIKit 샘플 앱을 제공한다. 라이브러리 사용법의 실제 동작 예시이자 통합 테스트 역할을 겸한다.

#### 7.6.1 공통: AppLogger (로깅 백엔드 무관 패턴)

두 샘플 앱이 공유하는 로거. 콘솔 출력과 LogStore 기록을 분리하는 패턴을 보여준다.

```swift
// AppLogger.swift
import Foundation
import LogViewer

final class AppLogger {
  static let shared = AppLogger()

  private let category: String

  init(category: String = "App") {
    self.category = category
  }

  func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    print("ℹ️ [\(category)] \(message)")
    LogStore.shared.log(level: .notice, category: category, message: message,
                        file: file, function: function, line: line)
  }

  func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    print("⚠️ [\(category)] \(message)")
    LogStore.shared.log(level: .warning, category: category, message: message,
                        file: file, function: function, line: line)
  }

  func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    print("❌ [\(category)] \(message)")
    LogStore.shared.log(level: .error, category: category, message: message,
                        file: file, function: function, line: line)
  }
}
```

#### 7.6.2 SwiftUI 샘플 앱

**SwiftUIExampleApp.swift:**

```swift
import SwiftUI
import LogViewer

@main
struct SwiftUIExampleApp: App {
  init() {
    // (선택) Configuration
    LogViewer.configure { config in
      config.maxLogCount = 1000
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .logViewer()  // 이 한 줄로 shake → 로그 뷰어 완성
    }
  }
}
```

**ContentView.swift:**

```swift
import SwiftUI
import LogViewer

struct ContentView: View {
  private let logger = AppLogger(category: "UI")
  private let networkLogger = AppLogger(category: "Network")
  @State private var counter = 0

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("LogViewer Demo")
          .font(.title)

        Text("기기를 흔들면 로그 뷰어가 나타납니다")
          .font(.caption)
          .foregroundStyle(.secondary)

        Divider()

        // 다양한 레벨의 로그 생성 버튼들
        Button("INFO 로그 생성") {
          counter += 1
          logger.info("버튼 탭 #\(counter)")
        }

        Button("WARNING 로그 생성") {
          logger.warning("디스크 용량이 부족합니다 (남은: 120MB)")
        }

        Button("ERROR 로그 생성") {
          logger.error("결제 실패: 카드 한도 초과")
        }

        Button("네트워크 로그 생성") {
          networkLogger.info("GET /api/users → 200 OK (132ms)")
          networkLogger.warning("GET /api/products → 429 Too Many Requests")
          networkLogger.error("POST /api/orders → 500 Internal Server Error")
        }

        Divider()

        // 프로그래매틱 트리거
        Button("로그 뷰어 직접 열기") {
          LogViewer.show()
        }
      }
      .padding()
      .navigationTitle("SwiftUI Example")
    }
  }
}
```

#### 7.6.3 UIKit 샘플 앱

**AppDelegate.swift:**

```swift
import UIKit
import LogViewer

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configuration (선택)
    LogViewer.configure { config in
      config.maxLogCount = 1000
    }

    // shake 시 자동으로 로그 뷰어 표시
    LogViewer.install()

    return true
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
}
```

**SceneDelegate.swift:**

```swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UINavigationController(rootViewController: ViewController())
    window.makeKeyAndVisible()
    self.window = window
  }
}
```

**ViewController.swift:**

```swift
import UIKit
import LogViewer

class ViewController: UIViewController {
  private let logger = AppLogger(category: "UI")
  private let networkLogger = AppLogger(category: "Network")
  private var counter = 0

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "UIKit Example"
    view.backgroundColor = .systemBackground
    setupUI()
    logger.info("ViewController loaded")
  }

  private func setupUI() {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = UILabel()
    titleLabel.text = "LogViewer Demo"
    titleLabel.font = .preferredFont(forTextStyle: .title1)
    titleLabel.textAlignment = .center

    let subtitleLabel = UILabel()
    subtitleLabel.text = "기기를 흔들면 로그 뷰어가 나타납니다"
    subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.textAlignment = .center

    let infoButton = makeButton(title: "INFO 로그 생성", action: #selector(infoTapped))
    let warnButton = makeButton(title: "WARNING 로그 생성", action: #selector(warnTapped))
    let errorButton = makeButton(title: "ERROR 로그 생성", action: #selector(errorTapped))
    let networkButton = makeButton(title: "네트워크 로그 생성", action: #selector(networkTapped))
    let showButton = makeButton(title: "로그 뷰어 직접 열기", action: #selector(showLogViewer))

    [titleLabel, subtitleLabel, infoButton, warnButton, errorButton, networkButton, showButton]
      .forEach { stack.addArrangedSubview($0) }

    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
      stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
    ])
  }

  private func makeButton(title: String, action: Selector) -> UIButton {
    var config = UIButton.Configuration.filled()
    config.title = title
    config.cornerStyle = .medium
    let button = UIButton(configuration: config)
    button.addTarget(self, action: action, for: .touchUpInside)
    return button
  }

  @objc private func infoTapped() {
    counter += 1
    logger.info("버튼 탭 #\(counter)")
  }

  @objc private func warnTapped() {
    logger.warning("디스크 용량이 부족합니다 (남은: 120MB)")
  }

  @objc private func errorTapped() {
    logger.error("결제 실패: 카드 한도 초과")
  }

  @objc private func networkTapped() {
    networkLogger.info("GET /api/users → 200 OK (132ms)")
    networkLogger.warning("GET /api/products → 429 Too Many Requests")
    networkLogger.error("POST /api/orders → 500 Internal Server Error")
  }

  @objc private func showLogViewer() {
    LogViewer.show(from: self)  // 수동 트리거
  }
}
```

#### 7.6.4 샘플 앱 검증 체크리스트

두 샘플 앱 모두 아래 시나리오를 검증할 수 있어야 한다:

- [ ] 각 버튼 탭 → 로그 생성 확인
- [ ] 기기 shake → 햅틱 + 로그 뷰어 sheet 표시
- [ ] "로그 뷰어 직접 열기" 버튼 → programmatic trigger 동작
- [ ] 레벨 임계값 필터 → "WARN+" 선택 시 warning/error만 표시
- [ ] Category 필터 → "Network" 선택 시 해당 카테고리만 표시
- [ ] 검색어 입력 → 하이라이트 + ↑↓ 순환 네비게이션
- [ ] 로그 탭 → 상세 뷰 (file, function, line 정보)
- [ ] 로그 길게 누르기 → contextMenu에서 복사
- [ ] 전체 공유 → 텍스트/파일 내보내기
- [ ] Release 빌드 → `isEnabled` false → 모든 동작 no-op 확인

---

## 8. 제약 사항과 알려진 이슈

| 항목 | 설명 | 완화 방법 |
|---|---|---|
| **앱 재시작 시 로그 휘발** | 메모리만 사용 → 앱 종료 시 사라짐 | 파일 persist 옵션 추가 (향후 확장) |
| **직접 기록한 로그만 수집** | `LogStore.shared.log()`가 호출된 로그만 수집. 시스템 로그나 외부 라이브러리 로그는 안 잡힘 | `OSLogStore` API (iOS 15+) 사용으로 확장 가능 |
| **UIWindow extension override 경고** | 일부 Xcode 버전에서 `open override`에 경고 출력 | 실제 동작에 영향 없음 |
| **여러 Window 환경** | `UIWindow` extension은 모든 window에 적용되므로 다중 디스플레이 앱에서는 중복 알림 가능성 | notification 발행 시 디바운스 |
| **시뮬레이터 햅틱 없음** | 실기기에서만 체감 | 테스트 시 실기기 사용 또는 `LogViewer.show()` 사용 |
| **Dark Mode** | 노란/회색 하이라이트 색이 dark mode에서 덜 명확할 수 있음 | 커스텀 Color로 dark/light 분리 |
| **긴 메시지 줄바꿈** | 모노스페이스 폰트로 렌더링되므로 너무 긴 메시지는 줄바꿈됨 | 탭 → 상세 뷰에서 전체 확인, `.textSelection(.enabled)`로 복사 |
| **검색 성능** | 로그 500개 × 각 메시지 길이에 대한 매 recalculate은 O(n·m). 500개 정도에서는 충분히 빠름 | 더 많은 로그를 지원하려면 debounce가 이미 적용됨 |
| **topViewController 탐색 한계** | UIKit `LogViewer.install()` 사용 시, 복잡한 VC 계층(커스텀 container VC 등)에서 최상위 VC를 정확히 찾지 못할 수 있음 | `LogViewer.show(from:)`으로 직접 VC 지정 |
| **UIHostingController 래핑** | UIKit에서 뷰어 표시 시 UIHostingController로 감싸므로, UIKit 앱의 네비게이션 흐름과 완전히 일체화되지는 않음 | modal presentation으로 독립 표시하므로 실사용에는 문제 없음 |

---

## 9. 확장 아이디어

### 9.1 파일 기반 persist

앱 재시작 후에도 로그를 유지하려면 append마다 파일에 기록하거나 주기적으로 flush:

```swift
private let fileHandle: FileHandle?  // Documents/Logs/session.log
private func appendToFile(_ entry: LogEntry) {
  let line = entry.formatted(includeLocation: true) + "\n"
  fileHandle?.write(line.data(using: .utf8)!)
}
```

**주의:** 파일 크기 제한(예: 10MB)과 rotate 로직 필요.

### 9.2 다중 세션 지원

앱 실행 세션을 구분하여 "이전 세션 로그 보기" 메뉴 추가:

```swift
LogStore.shared.sessions: [LogSession]
struct LogSession {
  let id: UUID
  let startedAt: Date
  let entries: [LogEntry]
}
```

### 9.3 OSLogStore 통합

iOS 15+의 `OSLogStore`를 사용하면 앱이 생성하지 않은 시스템/외부 라이브러리 로그까지 읽을 수 있다:

```swift
import OSLog

let store = try OSLogStore(scope: .currentProcessIdentifier)
let position = store.position(timeIntervalSinceLatestBoot: 0)
let entries = try store.getEntries(at: position)
  .compactMap { $0 as? OSLogEntryLog }
```

단, 권한과 성능 이슈가 있음.

### 9.4 정규식 검색

현재 단순 문자열 검색을 정규식으로 확장:

```swift
let regex = try? Regex(searchText)
```

iOS 16+의 `Regex` 리터럴 활용 가능.

### 9.5 컬러 / 심볼 테마

`LogViewerConfiguration`에 테마 옵션 추가:

```swift
config.theme = .xcode  // .xcode | .solarized | .dracula
```

### 9.6 로그 전송 기능

원격 QA 지원을 위한 옵션 기능 (별도 extension 타겟):
- HTTP POST로 실시간 전송
- WebSocket으로 실시간 대시보드 연결
- 크래시 직전 N개 로그를 Sentry/Crashlytics에 첨부

단, 기본 LogViewer와는 레이어 분리할 것 (§1.3 비목표).

### 9.7 View 컴포넌트 재사용

`LogViewerView` 전체가 아니라 `LogListView`, `LogFilterBar` 같은 부분 컴포넌트를 public으로 노출하면 사용자가 자신의 디버그 화면에 조립 가능.

### 9.8 시간 범위 필터

특정 시간대의 로그만 표시:
- "최근 1분", "최근 5분" 같은 프리셋
- 또는 시작/끝 시간 직접 지정

---

## 10. 참고 자료

### Apple API 문서

- [`os.Logger`](https://developer.apple.com/documentation/os/logger) — 로깅 기본 API
- [`OSLogStore`](https://developer.apple.com/documentation/oslog/oslogstore) — 시스템 로그 스트림 읽기
- [`UIResponder.motionBegan(_:with:)`](https://developer.apple.com/documentation/uikit/uiresponder/1621106-motionbegan) — motion 이벤트 후킹
- [`AttributedString`](https://developer.apple.com/documentation/foundation/attributedstring) — 부분 속성 적용 텍스트
- [`ShareLink`](https://developer.apple.com/documentation/swiftui/sharelink) — iOS 16+ SwiftUI 공유 API
- [`UINotificationFeedbackGenerator`](https://developer.apple.com/documentation/uikit/uinotificationfeedbackgenerator) — 햅틱 피드백
- [`@Observable`](https://developer.apple.com/documentation/observation/observable()) — iOS 17+ SwiftUI 관찰 매크로
- [`ScrollViewReader`](https://developer.apple.com/documentation/swiftui/scrollviewreader) — 프로그래매틱 스크롤
- [`UIHostingController`](https://developer.apple.com/documentation/swiftui/uihostingcontroller) — SwiftUI 뷰를 UIKit에서 호스팅

### 관련 오픈소스 프로젝트 (참고용)

- [**CocoaDebug**](https://github.com/CocoaDebug/CocoaDebug) — 종합 iOS 디버그 도구 (로그/네트워크/crash)
- [**Logging**](https://github.com/apple/swift-log) — Apple 공식 Swift 로깅 API
- [**Puppy**](https://github.com/sushichop/Puppy) — 파일 기반 Swift 로깅

### 설계 참고

- Xcode Console 검색 UX (`⌘F` → 검색창 + ↑↓ 버튼 + 카운트)
- SF Symbols의 "hand.tap", "doc.text.magnifyingglass" 등 아이콘 활용
- macOS Console.app의 OSLog 필터/검색 인터페이스

---

## 부록 A: 최소 구현 체크리스트

문서만 보고 바닥부터 구현할 때 순서대로 확인할 항목:

**모델·저장소:**
- [ ] `LogEntry` struct와 `Level` enum 정의 (Identifiable, Equatable, Comparable)
- [ ] `LogStore` 싱글톤 class (@Observable, circular buffer, main thread dispatch)
- [ ] `LogStore.log()` 편의 메서드
- [ ] `LogStore.exportAsText` / `exportAsLogFile` 메서드
- [ ] `LogViewerConfiguration` 설정 객체

**트리거·연결:**
- [ ] `UIWindow` extension에 `motionBegan` override
- [ ] `Notification.Name.deviceDidShake` 정의
- [ ] `LogViewerModifier` + `View.logViewer()` 확장 (shake + sheet + 햅틱 내장)
- [ ] `View.onShake(perform:)` 확장 (커스텀 동작용)
- [ ] `LogViewer.configure()` — Configuration 적용
- [ ] `LogViewer.install()` — UIKit 자동 트리거 (shake → topVC → present)
- [ ] `LogViewer.show(from:)` — UIKit 수동 트리거
- [ ] `LogViewer.show()` — programmatic trigger

**뷰어 UI:**
- [ ] `LogViewerView` NavigationStack + VStack 기본 레이아웃
- [ ] 레벨 임계값 필터 bar (전체/LOG+/NOTICE+/WARN+/ERROR+/CRITICAL+/FAULT)
- [ ] Category 필터 + Location toggle chip
- [ ] Search navigation bar (count + prev/next buttons, 순환 로직)
- [ ] 검색 debounce (200ms)
- [ ] ScrollViewReader 기반 List + 초기 bottom 스크롤
- [ ] `LogEntryRow` (level badge, category, time, message)
- [ ] AttributedString 기반 검색어 하이라이트 (현재/일반 색상 구분)
- [ ] `onChange(of: searchText)` → debounce → matches 재계산
- [ ] `onChange(of: filters/entries)` → 즉시 matches 재계산
- [ ] `onChange(of: matches / currentMatchIndex)` → 스크롤
- [ ] 탭 → `LogEntryDetailView` (상세 정보)
- [ ] 길게 누르기 → contextMenu (1건 복사)
- [ ] Toolbar menu: 서브메뉴 공유(텍스트/.log) + 초기화

**통합 테스트:**
- [ ] SwiftUI 앱: `.logViewer()` 연결 → 실기기 shake → sheet + 햅틱 확인
- [ ] UIKit 앱: `LogViewer.install()` → 실기기 shake → sheet 확인
- [ ] UIKit 앱: `LogViewer.show(from:)` → 버튼 탭 → sheet 확인
- [ ] `LogViewer.show()` programmatic trigger 확인
- [ ] print/os.Logger/swift-log 각각에서 `LogStore.shared.log()` 호출 → 뷰어에 표시 확인
- [ ] 레벨 임계값 필터 → "WARN+" 선택 시 warning/error/critical/fault만 표시
- [ ] 검색 + 순환 네비게이션 → 공유 전체 플로우 수동 검증
- [ ] Release 빌드에서 `#if DEBUG` 가드로 LogViewer symbol 미포함 확인

---

**문서 버전:** 2.0
**작성일:** 2026-04-12
**대상 iOS 버전:** iOS 17+ (iOS 16 호환성은 `@Observable` → `ObservableObject`로 다운그레이드 필요)
