// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tinyeval",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "Tinyeval", targets: ["Tinyeval"]),
        .executable(name: "tinyeval", targets: ["TinyevalCommand"]),
    ],
    targets: [
        .target(name: "Tinyeval", dependencies: ["TinyevalStdout"]),
        // A C constructor: it moves stdout to stderr when the worker starts, before any Swift code runs.
        .target(name: "TinyevalStdout"),
        // The tinyeval command. It doesn't link Tinyeval, since the runner needs the real stdout.
        .executableTarget(name: "TinyevalCommand", resources: [.copy("tinyeval")]),
        .testTarget(name: "TinyevalTests", dependencies: ["Tinyeval", "TinyevalStdout"]),
    ]
)
