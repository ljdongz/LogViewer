import SwiftUI
import LogViewer

@main
struct SwiftUIExampleApp: App {
    init() {
        #if DEBUG
        LogViewer.isEnabled = true
        #endif
        LogViewer.configure { config in
            config.maxLogCount = 1000
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
