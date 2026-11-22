// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "spaces-layout",
    platforms: [.macOS("15.0")],
    dependencies: [
        // In-app updates (docs/distribution.md, M5). Exact version: a release must not change it by itself.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "spaces-layout",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources",
            // Sparkle.framework sits in SpaceDock.app/Contents/Frameworks (tools/make-app.sh).
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
