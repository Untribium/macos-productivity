// swift-tools-version:6.2
// The floor is the oldest toolchain a machine we build on has (Swift 6.2,
// docs/verification/*-overlay-env-*.md). Deployment target 26 so the old work
// machine can run it too.
import PackageDescription

let mainActor: [SwiftSetting] = [.defaultIsolation(MainActor.self)]

let package = Package(
  name: "Overlay",
  platforms: [.macOS(.v26)],
  products: [
    .library(name: "OverlayKit", targets: ["OverlayKit"]),
    .executable(name: "OverlaySpike", targets: ["OverlaySpike"]),
  ],
  targets: [
    // The framework: panel, hotkey, chooser. Knows nothing about any app.
    .target(name: "OverlayKit", swiftSettings: mainActor),
    // The spike: a running-apps launcher, to test the feel on each machine.
    .executableTarget(name: "OverlaySpike", dependencies: ["OverlayKit"], swiftSettings: mainActor),
  ]
)
