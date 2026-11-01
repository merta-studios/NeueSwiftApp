import Foundation

/// Zentrale App-Metadaten für die Einstiegsansicht.
///
/// Die Werte müssen zu `Package.swift` passen. `Tests/CoreTests` liest das
/// Manifest und schlägt fehl, wenn Bundle-ID, App-Name oder Version
/// auseinanderlaufen. Plattformunabhängig (nur Foundation), damit der Test
/// unter Linux läuft.
enum AppMetadata {
    /// Platzhalter, solange kein endgültiger App-Name festgelegt ist.
    static let displayName = "NeueSwiftApp"

    /// Platzhalter-Bundle-ID. Vor dem ersten Release ersetzen.
    static let bundleIdentifier = "com.example.neueswiftapp"

    static let shortVersion = "1.0"
    static let buildNumber = "1"
    static let minimumIOSVersion = "17.0"

    /// Geparste Kurzversion – `nil`, wenn `shortVersion` kein SemVer ist.
    static var version: SemanticVersion? { SemanticVersion(shortVersion) }

    static var versionLabel: String {
        "Version \(shortVersion) (\(buildNumber))"
    }

    static var aboutLine: String {
        "\(displayName) · \(versionLabel)"
    }

    /// `true`, solange die Bundle-ID nur der dokumentierte Platzhalter ist.
    static var isPlaceholderBundleIdentifier: Bool {
        bundleIdentifier.hasPrefix("com.example.")
    }

    /// Grobe Prüfung einer Reverse-DNS-Bundle-ID (Apple verlangt mehr, das
    /// prüft erst Xcode/App Store Connect).
    static func isValidBundleIdentifier(_ candidate: String) -> Bool {
        let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2 else { return false }

        for part in parts {
            guard !part.isEmpty, part.count <= 63 else { return false }
            for character in part {
                let allowed =
                    (character.isASCII && character.isLetter)
                    || (character.isASCII && character.isNumber)
                    || character == "-"
                guard allowed else { return false }
            }
            guard part.first != "-", part.last != "-" else { return false }
        }

        guard let topLevel = parts.first, topLevel.count >= 2 else { return false }
        guard let first = topLevel.first, first.isASCII, first.isLetter else { return false }
        return true
    }
}
