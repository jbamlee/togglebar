// swift-tools-version:5.9
import PackageDescription

// ToggleBar — macOS-only personal "toggle hub".
// One data source (toggles.json) + one logic core (ToggleKit),
// shared by two frontends: a CLI and a menu bar app.
let package = Package(
    name: "togglebar",
    platforms: [.macOS(.v13)],
    targets: [
        // Logic single-source. Both frontends depend on this.
        .target(name: "ToggleKit"),
        // Frontend 1: command-line interface (also the gateway for Raycast / Shortcuts / hotkeys).
        .executableTarget(name: "togglebar", dependencies: ["ToggleKit"]),
        // Frontend 2: SwiftUI menu bar app.
        .executableTarget(name: "ToggleBarApp", dependencies: ["ToggleKit"]),
    ]
)
