import SwiftUI
import LogViewer

// This example only demonstrates the "button trigger" pattern.
// Shake-to-show requires a custom UIWindow subclass — see
// Examples/UIKitExample (ShakeWindow) for that pattern.
struct ContentView: View {
    private let logger = AppLogger(category: "UI")
    private let networkLogger = AppLogger(category: "Network")
    @State private var counter = 0
    @State private var showLog = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("LogViewer Demo")
                    .font(.title)

                Text("Tap the 'Show Logs' button below to open the log viewer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Button("Generate INFO log") {
                    counter += 1
                    logger.info("Button tap #\(counter)")
                }

                Button("Generate WARNING log") {
                    logger.warning("Low disk space (remaining: 120MB)")
                }

                Button("Generate ERROR log") {
                    logger.error("Payment failed: card limit exceeded")
                }

                Button("Generate Network logs") {
                    networkLogger.info("GET /api/users → 200 OK (132ms)")
                    networkLogger.warning("GET /api/products → 429 Too Many Requests")
                    networkLogger.error("POST /api/orders → 500 Internal Server Error")
                }

                Divider()

                // Trigger: present LogViewerView as a sheet via an explicit button.
                Button("Show Logs") {
                    showLog = true
                }
            }
            .padding()
            .navigationTitle("SwiftUI Example")
            .sheet(isPresented: $showLog) {
                LogViewerView()
            }
        }
    }
}
