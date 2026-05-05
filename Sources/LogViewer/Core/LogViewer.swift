import Foundation

/// Namespace holding the activation toggle and global configuration of the LogViewer library.
///
/// This enum is not instantiated; use it through its static members. The library does not
/// dictate how the UI is presented — the host app is free to present ``LogViewerView`` in
/// any way it likes. See <doc:PresentationRecipes> for trigger patterns.
///
/// ## Activation
/// The default is `false`, so the host app must explicitly turn it on.
///
/// ```swift
/// #if DEBUG
/// LogViewer.isEnabled = true
/// LogViewer.configure {
///     $0.maxLogCount = 1000
///     $0.dateFormat  = "HH:mm:ss.SSS"
/// }
/// #endif
/// ```
///
/// ## Topics
/// ### Activation
/// - ``isEnabled``
/// ### Configuration
/// - ``configure(_:)``
public enum LogViewer {

    // MARK: - Activation Control

    /// Whether the library is active.
    ///
    /// Defaults to `false`. A library shipped via SPM is compiled in release mode, so an
    /// internal `#if DEBUG` cannot detect the host app's build mode — activation must be
    /// decided by the host app itself.
    ///
    /// While `false`, ``LogStore/log(level:category:message:file:function:line:)`` is a
    /// no-op, so the call cost is negligible even in release builds.
    ///
    /// See <doc:Activation> for activation patterns.
    public static var isEnabled: Bool = false

    // MARK: - Configuration

    private static var configuration = LogViewerConfiguration()

    /// Updates the global ``LogViewerConfiguration``.
    ///
    /// Receives the current configuration through an `inout` closure and lets you mutate
    /// it freely. Becomes a no-op when ``isEnabled`` is `false`.
    ///
    /// - Parameter block: A closure that mutates the configuration.
    ///
    /// ```swift
    /// LogViewer.configure {
    ///     $0.maxLogCount = 2000
    ///     $0.dateFormat  = "yyyy-MM-dd HH:mm:ss"
    /// }
    /// ```
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
