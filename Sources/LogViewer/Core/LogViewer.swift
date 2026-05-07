import Foundation

/// Namespace holding the activation switch and global configuration of the LogViewer library.
///
/// This enum is not instantiated; use it through its static members. The library does not
/// dictate how the UI is presented — the host app is free to present ``LogViewerView`` in
/// any way it likes. See <doc:PresentationRecipes> for trigger patterns.
///
/// ## Activation
/// The library defaults to disabled. Call ``setup(_:)`` from the host app's entry point
/// inside `#if DEBUG` to activate it.
///
/// ```swift
/// #if DEBUG
/// LogViewer.setup {
///     $0.maxLogCount = 1000
///     $0.dateFormat  = "HH:mm:ss.SSS"
/// }
/// #endif
/// ```
///
/// ## Topics
/// ### Activation
/// - ``setup(_:)``
/// - ``isEnabled``
public enum LogViewer {

    // MARK: - Activation Control

    /// Whether the library is active.
    ///
    /// Defaults to `false`. Becomes `true` after ``setup(_:)`` is called.
    ///
    /// While `false`, ``LogStore/log(level:category:message:file:function:line:)`` is a
    /// no-op, so the call cost is negligible even in release builds.
    ///
    /// The setter is internal: external callers cannot toggle this directly. Use
    /// ``setup(_:)`` to activate. See <doc:Activation> for activation patterns.
    public internal(set) static var isEnabled: Bool = false

    // MARK: - Configuration

    private static var configuration = LogViewerConfiguration()

    /// Activates LogViewer and optionally applies configuration.
    ///
    /// Call this once at the host app's entry point, inside `#if DEBUG`. Calling without
    /// a closure simply enables the library with default configuration; pass a closure to
    /// enable and configure in one step.
    ///
    /// ```swift
    /// // Enable with defaults
    /// LogViewer.setup()
    ///
    /// // Enable and configure
    /// LogViewer.setup {
    ///     $0.maxLogCount = 2000
    ///     $0.dateFormat  = "yyyy-MM-dd HH:mm:ss"
    /// }
    /// ```
    ///
    /// - Parameter block: An optional closure that mutates the configuration.
    public static func setup(
        _ block: ((inout LogViewerConfiguration) -> Void)? = nil
    ) {
        isEnabled = true
        guard let block else { return }
        block(&configuration)
        let max = configuration.maxLogCount
        Task { @MainActor in
            LogStore.shared.maxCount = max
        }
    }

    /// Updates the global ``LogViewerConfiguration``.
    ///
    /// - Parameter block: A closure that mutates the configuration.
    @available(*, deprecated, message: "Use LogViewer.setup { ... } instead. setup activates the library and applies configuration in a single call.")
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
