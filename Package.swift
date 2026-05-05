// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LogViewer",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "LogViewer", targets: ["LogViewer"]),
    ],
    targets: [
        .target(
            name: "LogViewer",
            dependencies: []
        ),
        .testTarget(
            name: "LogViewerTests",
            dependencies: ["LogViewer"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
