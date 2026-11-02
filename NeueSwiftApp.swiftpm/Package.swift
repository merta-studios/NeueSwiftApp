// swift-tools-version: 5.9

// Manifest des Swift-Playgrounds-App-Pakets.
//
// Swift Playgrounds auf dem iPad darf diese Datei beim Bearbeiten neu
// schreiben; deshalb bleibt sie bewusst so nah wie möglich am von Playgrounds
// erzeugten Format. Nach jeder Änderung von Hand prüfen:
//   Tests/CoreTests vergleicht Bundle-ID, App-Name und Version mit
//   NeueSwiftApp.swiftpm/Core/AppMetadata.swift.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "NeueSwiftApp",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "NeueSwiftApp",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.neueswiftapp",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .pad,
                .phone,
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight,
                .portraitUpsideDown(.when(deviceFamilies: [.pad])),
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            resources: [
                .process("Assets.xcassets"),
                .copy("Core/Ink/HERSHEY-LICENSE.txt"),
            ]
        )
    ]
)
