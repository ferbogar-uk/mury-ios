// swift-tools-version: 5.9
// Compiles the app's Foundation-only logic files IN PLACE (symlink-free, by path)
// so they can be tested on Linux without touching the iOS app target.
import PackageDescription

let package = Package(
    name: "CoreLogic",
    targets: [
        .target(
            name: "CoreLogic",
            path: "Sources/CoreLogic"
        ),
        .testTarget(
            name: "CoreLogicTests",
            dependencies: ["CoreLogic"],
            path: "Tests/CoreLogicTests"
        ),
    ]
)