# ``LogViewer``

iOS 앱을 위한 인-앱 로그 뷰어 SwiftUI 컴포넌트.

## Overview

LogViewer는 두 가지 책임만 집니다:

1. **로그 캡처** — ``LogStore``가 레벨/카테고리/위치 메타와 함께 ring-buffer로 저장
2. **로그 화면** — ``LogViewerView``가 검색·필터·공유·export를 제공

"화면을 언제·어떻게 띄울지"는 앱마다 정책이 달라 라이브러리가 떠안지 않습니다. 디버그 메뉴, 제스처, 흔들기 등 어떤 방식이든 `LogViewerView()`를 직접 띄우면 됩니다 — <doc:PresentationRecipes>의 예시 참고.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Activation>

### Presenting the Viewer

- <doc:PresentationRecipes>

### Capturing Logs

- ``LogStore``
- ``LogEntry``

### Configuration

- ``LogViewer/LogViewer``
- ``LogViewerConfiguration``

### The Viewer Screen

- ``LogViewerView``
