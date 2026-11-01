import Foundation

// Regressionstests der plattformunabhängigen App-Logik.
//
// Geprüft wird echter Code, den die App benutzt: Core/SemanticVersion.swift und
// Core/AppMetadata.swift. Start über Tests/run-core-tests.sh (Linux und macOS,
// ohne iOS-SDK, ohne Xcode). Kein XCTest, damit derselbe Test ohne
// Swift-Package-Infrastruktur mit `swiftc` läuft.

private var checks = 0
private var failures: [String] = []

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    checks += 1
    if !condition() {
        failures.append("\((file as NSString).lastPathComponent):\(line): \(message)")
    }
}

private func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    checks += 1
    if actual != expected {
        failures.append(
            "\((file as NSString).lastPathComponent):\(line): \(message) – "
                + "erwartet \(expected), erhalten \(actual)"
        )
    }
}

private func expectNil<T>(
    _ actual: T?,
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
) {
    checks += 1
    if let actual {
        failures.append(
            "\((file as NSString).lastPathComponent):\(line): \(message) – erhalten \(actual)"
        )
    }
}

// MARK: - Versionsnummern lesen

expectEqual(
    SemanticVersion("1.0.0"),
    SemanticVersion(major: 1, minor: 0, patch: 0),
    "Einfache Version"
)
expectEqual(SemanticVersion("  1.2.3  "), SemanticVersion(major: 1, minor: 2, patch: 3), "Leerraum")
expectEqual(
    SemanticVersion("1.2.3-alpha.1+build.5"),
    SemanticVersion(major: 1, minor: 2, patch: 3, prerelease: "alpha.1"),
    "Build-Metadaten werden ignoriert"
)
expectEqual(
    SemanticVersion("1.2.3+build"),
    SemanticVersion(major: 1, minor: 2, patch: 3),
    "Nur Build-Metadaten"
)
expectNil(SemanticVersion(""), "Leere Zeichenkette")
expectNil(SemanticVersion("   "), "Nur Leerraum")
expectNil(SemanticVersion("1.0"), "Zwei Komponenten reichen nicht")
expectNil(SemanticVersion("1.0.0.0"), "Vier Komponenten sind kein SemVer")
expectNil(SemanticVersion("v1.0.0"), "Kein Präfix erlaubt")
expectNil(SemanticVersion("01.2.3"), "Führende Null in der Hauptversion")
expectNil(SemanticVersion("1.2.3-"), "Leere Vorabversion")
expectNil(SemanticVersion("1.2.3-alpha..1"), "Leere Kennung in der Vorabversion")
expectNil(SemanticVersion("1.2.3-al!pha"), "Unzulässiges Zeichen in der Vorabversion")
expectNil(SemanticVersion("1.2.3-01"), "Führende Null in numerischer Kennung")
expectNil(SemanticVersion("1.2.x"), "Buchstabe statt Zahl")
expectNil(SemanticVersion("-1.2.3"), "Negatives Vorzeichen")
expectNil(SemanticVersion("9999999999999999999999.0.0"), "Zahl außerhalb von Int")

expectEqual(
    SemanticVersion("1.2.3-rc.1")?.description ?? "",
    "1.2.3-rc.1",
    "Beschreibung enthält die Vorabversion"
)
expectEqual(SemanticVersion("1.2.3+meta")?.description ?? "", "1.2.3", "Build-Metadaten entfallen")
expectNil(
    SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: ""),
    "Leere Vorabversion im Init"
)
expectEqual(
    SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: ""),
    SemanticVersion(major: 1, minor: 0, patch: 0),
    "Leere Vorabversion entspricht keiner Vorabversion"
)

// MARK: - Versionsordnung nach SemVer

private let precedence = [
    "1.0.0-alpha",
    "1.0.0-alpha.1",
    "1.0.0-alpha.beta",
    "1.0.0-beta",
    "1.0.0-beta.2",
    "1.0.0-beta.11",
    "1.0.0-rc.1",
    "1.0.0",
]
for index in 1..<precedence.count {
    let lower = SemanticVersion(precedence[index - 1])
    let higher = SemanticVersion(precedence[index])
    expect(lower != nil, "Beispielversion \(precedence[index - 1]) ist lesbar")
    expect(higher != nil, "Beispielversion \(precedence[index]) ist lesbar")
    guard let lower, let higher else { continue }
    expect(lower < higher, "\(lower) ist älter als \(higher)")
    expect(!(higher < lower), "\(higher) ist nicht älter als \(lower)")
    expect(higher > lower, "\(higher) ist neuer als \(lower)")
}

expect(
    SemanticVersion("1.0.1")! > SemanticVersion("1.0.0")!,
    "Patch-Version zählt"
)
expect(
    SemanticVersion("2.0.0")! > SemanticVersion("1.99.99")!,
    "Hauptversion hat Vorrang"
)
expect(
    SemanticVersion("1.1.0")! > SemanticVersion("1.0.99")!,
    "Minor-Version hat Vorrang vor Patch"
)
expect(
    SemanticVersion("1.0.0+build.2")! == SemanticVersion("1.0.0+build.1")!,
    "Build-Metadaten ändern die Ordnung nicht"
)
expect(
    !(SemanticVersion("1.0.0-alpha")! < SemanticVersion("1.0.0-alpha")!),
    "Gleiche Versionen sind nicht geordnet"
)
expect(
    SemanticVersion("1.0.0-alpha.2")! < SemanticVersion("1.0.0-alpha.10")!,
    "Numerische Kennungen werden als Zahl verglichen"
)
expect(
    SemanticVersion("1.0.0-alpha")! < SemanticVersion("1.0.0-alpha.1")!,
    "Kürzere Kennungsliste steht vorn"
)

// MARK: - App-Metadaten

expectEqual(AppMetadata.displayName, "NeueSwiftApp", "Anzeigename")
expectEqual(AppMetadata.version, SemanticVersion("1.0"), "Kurzversion ist lesbar")
expectEqual(AppMetadata.versionLabel, "Version 1.0 (1)", "Versionszeile")
expectEqual(AppMetadata.aboutLine, "NeueSwiftApp · Version 1.0 (1)", "Zeile der Einstiegsansicht")
expect(AppMetadata.isPlaceholderBundleIdentifier, "Bundle-ID ist noch ein Platzhalter")
expect(
    AppMetadata.isValidBundleIdentifier(AppMetadata.bundleIdentifier),
    "Platzhalter-Bundle-ID ist formal gültig"
)

// MARK: - Bundle-ID prüfen

expect(AppMetadata.isValidBundleIdentifier("com.example.neueswiftapp"), "Übliche Reverse-DNS-ID")
expect(AppMetadata.isValidBundleIdentifier("de.merta.app"), "Dreiteilig")
expect(!AppMetadata.isValidBundleIdentifier("neueswiftapp"), "Ohne Punkt keine Bundle-ID")
expect(!AppMetadata.isValidBundleIdentifier(""), "Leere Bundle-ID")
expect(!AppMetadata.isValidBundleIdentifier("com..app"), "Leere Komponente")
expect(!AppMetadata.isValidBundleIdentifier("com.example.app-"), "Bindestrich am Ende")
expect(!AppMetadata.isValidBundleIdentifier("com.-example.app"), "Bindestrich am Anfang")
expect(!AppMetadata.isValidBundleIdentifier("1com.example.app"), "Beginnt mit Ziffer")
expect(!AppMetadata.isValidBundleIdentifier("c.example.app"), "Top-Level zu kurz")
expect(!AppMetadata.isValidBundleIdentifier("com.example.neue swiftapp"), "Leerzeichen")
expect(!AppMetadata.isValidBundleIdentifier("com.example.neue_swiftapp"), "Unterstrich")

// MARK: - Übereinstimmung mit dem Paketmanifest

private let root = ProcessInfo.processInfo.environment["NEUESWIFT_ROOT"] ?? "."
private let manifestPath = root + "/NeueSwiftApp.swiftpm/Package.swift"
private let manifest = try? String(contentsOfFile: manifestPath, encoding: .utf8)

expect(manifest != nil, "Paketmanifest lesbar: \(manifestPath)")
if let manifest {
    expect(
        manifest.contains("\"\(AppMetadata.bundleIdentifier)\""),
        "Manifest nutzt dieselbe Bundle-ID wie AppMetadata"
    )
    expect(
        manifest.contains("name: \"\(AppMetadata.displayName)\""),
        "Manifest nutzt denselben App-Namen wie AppMetadata"
    )
    expect(
        manifest.contains("displayVersion: \"\(AppMetadata.shortVersion)\""),
        "Manifest nutzt dieselbe Kurzversion wie AppMetadata"
    )
    expect(
        manifest.contains("bundleVersion: \"\(AppMetadata.buildNumber)\""),
        "Manifest nutzt dieselbe Buildnummer wie AppMetadata"
    )
    expect(
        manifest.contains(".iOS(\"\(AppMetadata.minimumIOSVersion)\")"),
        "Manifest nutzt dieselbe Mindest-iOS-Version wie AppMetadata"
    )
    expect(manifest.contains("import AppleProductTypes"), "Manifest ist ein Playgrounds-App-Paket")
}

// MARK: - Ergebnis

if checks == 0 {
    FileHandle.standardError.write(Data("Keine einzige Prüfung gelaufen.\n".utf8))
    exit(1)
}

if failures.isEmpty {
    print("\(checks) Prüfungen erfolgreich.")
    exit(0)
}

private let summary = "\(failures.count) von \(checks) Prüfungen fehlgeschlagen:\n"
FileHandle.standardError.write(Data(summary.utf8))
for failure in failures {
    FileHandle.standardError.write(Data("  ✗ \(failure)\n".utf8))
}
exit(1)
