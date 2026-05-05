# Activation

`LogViewer.isEnabled`를 언제, 어떻게 켜고 끌지 정리합니다.

## Overview

``LogViewer/LogViewer``는 기본값이 `isEnabled = false`입니다.
이 값이 `false`인 동안에는 ``LogStore/log(level:category:message:file:function:line:)``가 no-op이 되어
엔트리를 전혀 보관하지 않습니다. 실수로 릴리스 빌드에 디버그 데이터가 쌓이는 사고를 막기 위한 안전장치입니다.

### 왜 라이브러리 내부에서 `#if DEBUG`로 처리하지 않나요?

Swift Package Manager는 의존 라이브러리를 거의 항상 release 컴파일 모드로 빌드합니다.
즉 **라이브러리 코드 안의 `#if DEBUG`는 사용자 앱이 Debug로 빌드되더라도 켜지지 않습니다.**
라이브러리 입장에서는 자기를 사용하는 앱의 빌드 모드를 알 수 없기 때문입니다.

대신 앱 측 `#if DEBUG` 블록에서 `LogViewer.isEnabled = true`를 명시적으로 호출하면,
사용자 앱의 빌드 모드를 기준으로 토글되어 디버그에서만 활성화되는 동작을 신뢰할 수 있게 됩니다.

### 권장 패턴

앱 진입점에서 한 번만 켭니다.

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

### TestFlight·릴리스에서 자동 비활성

별다른 작업이 필요 없습니다. `#if DEBUG` 블록은 Release / TestFlight Archive 빌드에서 컴파일에서 제외되므로
`isEnabled`는 기본값 `false`로 유지됩니다.

내부 QA 빌드에는 켜고 외부 배포에는 끄고 싶다면, 사용자 정의 컴파일 플래그(예: `-D INTERNAL_BUILD`)를 활용하세요.

```swift
#if DEBUG || INTERNAL_BUILD
LogViewer.isEnabled = true
#endif
```

### 런타임 토글

디버그 메뉴나 숨김 설정 화면에서 직접 켜고 끌 수도 있습니다.

```swift
Toggle("In-App Logger", isOn: Binding(
    get: { LogViewer.isEnabled },
    set: { LogViewer.isEnabled = $0 }
))
```

`isEnabled`를 `false`로 바꾸면 즉시 ``LogStore/log(level:category:message:file:function:line:)``가 no-op이 되어 새 로그 수집이 멈춥니다.
이미 캡처해 둔 엔트리는 ``LogStore/clear()``를 호출하기 전까지 그대로 유지됩니다.
다시 `true`로 설정하면 같은 ``LogStore/shared`` 인스턴스가 재사용됩니다.
