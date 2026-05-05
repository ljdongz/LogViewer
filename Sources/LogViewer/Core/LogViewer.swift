import Foundation

public enum LogViewer {

    // MARK: - Activation Control

    public static var isEnabled: Bool = false

    // MARK: - Configuration

    private static var configuration = LogViewerConfiguration()

    public static func configure(
        _ block: (inout LogViewerConfiguration) -> Void
    ) {
        guard isEnabled else { return }
        block(&configuration)
        let max = configuration.maxLogCount
        Task { @MainActor in
            LogStore.shared.maxCount = max
        }
    }

    static var dateFormat: String {
        configuration.dateFormat
    }
}
