import SwiftUI
import LogViewer

@main
struct SwiftUIExampleApp: App {
    init() {
        #if DEBUG
        LogViewer.setup { config in
            config.maxLogCount = 1000
        }
        DummyLogSeeder.seed()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
