# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-05-05

### Added
- `LogStore` — `@MainActor` 메모리 기반 ring-buffer 저장소. `LogStore.shared`로 접근하며 `@Published var entries: [LogEntry]`를 노출.
- `LogStore.log(level:category:message:file:function:line:)` — `nonisolated` 단일 진입점. 어느 스레드에서도 호출 가능 (내부에서 MainActor로 hop).
- `LogStore.clear()`, `LogStore.exportAsText(includeLocation:)`, `LogStore.exportAsLogFile(includeLocation:)`, `LogStore.availableCategories`.
- `LogEntry` — `id`, `timestamp`, `level`, `category`, `message`, `file`, `function`, `line` 메타데이터.
- `LogEntry.Level` — `.log`, `.notice`, `.warning`, `.error`, `.critical`, `.fault` (Comparable, Sendable).
- `LogViewerView` — SwiftUI 로그 뷰어 화면. 텍스트 검색 + 매치 하이라이트, 레벨/카테고리 필터, 행 단위 상세 보기, 텍스트 공유, `.log` 파일 export.
- `LogViewer.isEnabled` — 글로벌 활성화 스위치. 기본값 `false`. 사용자 앱이 `#if DEBUG` 안에서 명시적으로 `true`로 설정해야 로깅이 동작.
- `LogViewer.configure { ... }` — `LogViewerConfiguration` 변경 API. `maxLogCount`(기본 500), `dateFormat`(기본 `"HH:mm:ss.SSS"`).

### Notes
- 본 라이브러리는 **로그 화면 컴포넌트(`LogViewerView`)만 제공**합니다. 화면을 어떻게/언제 띄울지는 앱이 결정합니다 (sheet, NavigationLink, floating 버튼, 흔들기 감지 등 — README의 "화면 띄우기" 섹션 패턴 모음 참고).
- iOS 16.0+, Swift 6 toolchain 대상 (`swiftLanguageModes: [.v5]`).
- Swift Package Manager 전용 배포 (CocoaPods / Carthage 미지원).
- Privacy manifest는 Required Reasons API를 사용하지 않으므로 미포함.

[Unreleased]: https://github.com/<your-org>/LogViewer/compare/1.0.0...HEAD
[1.0.0]: https://github.com/<your-org>/LogViewer/releases/tag/1.0.0
