// swift-tools-version: 6.2
// MeridianCore: pure time logic for Meridian. Foundation only, no UI frameworks.
// Run the tests from this folder with:  swift test
import PackageDescription

let package = Package(
    name: "MeridianCore",
    platforms: [
        .iOS("26.0"),    // the app's minimum
        .macOS("15.0"),  // lets `swift test` run on the Mac without a simulator
    ],
    products: [
        .library(name: "MeridianCore", targets: ["MeridianCore"]),
    ],
    targets: [
        .target(name: "MeridianCore"),
        .testTarget(name: "MeridianCoreTests", dependencies: ["MeridianCore"]),
    ]
)
