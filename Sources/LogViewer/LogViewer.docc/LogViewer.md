# ``LogViewer``

An in-app log viewer SwiftUI component for iOS apps.

## Overview

LogViewer has only two responsibilities:

1. **Log capture** — ``LogStore`` stores entries in a ring buffer with level, category, and location metadata.
2. **Log screen** — ``LogViewerView`` provides search, filtering, sharing, and export.

"When and how to present the screen" is a per-app policy, so the library does not take it on. Whether through a debug menu, a gesture, or a shake, you simply present `LogViewerView()` directly — see the examples in <doc:PresentationRecipes>.

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
