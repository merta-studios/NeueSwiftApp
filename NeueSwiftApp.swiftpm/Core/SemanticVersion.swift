import Foundation

/// Versionsnummer nach SemVer 2.0.0: `major.minor.patch[-prerelease][+build]`.
///
/// Diese Datei gehört zur plattformunabhängigen App-Logik: nur Foundation,
/// kein SwiftUI/UIKit. Sie wird unter Linux mit dem echten Compiler geprüft und
/// getestet (`Tests/run-core-tests.sh`), damit Fehler nicht erst im iOS-Build
/// auffallen.
struct SemanticVersion: Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?

    init(major: Int, minor: Int, patch: Int, prerelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        if let prerelease, !prerelease.isEmpty {
            self.prerelease = prerelease
        } else {
            self.prerelease = nil
        }
    }

    /// Parst eine Versionsnummer. `nil` bei allem, was nicht eindeutig lesbar ist.
    init?(_ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Build-Metadaten (`+...`) sind für den Vergleich bedeutungslos.
        let withoutBuild = trimmed.split(
            separator: "+", maxSplits: 1, omittingEmptySubsequences: false
        )
        guard let core = withoutBuild.first else { return nil }

        let pieces = core.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = pieces.first?.split(separator: ".", omittingEmptySubsequences: false) ?? []
        guard numbers.count == 3 else { return nil }

        var parsed: [Int] = []
        for number in numbers {
            guard !number.isEmpty, number.allSatisfy({ $0.isASCII && $0.isNumber }),
                let value = Int(number)
            else {
                return nil
            }
            // „01.2.3“ ist kein gültiges SemVer.
            guard number.count == 1 || number.first != "0" else { return nil }
            parsed.append(value)
        }

        var candidate: String?
        if pieces.count == 2 {
            candidate = String(pieces[1])
            guard let candidate, Self.isValidPrerelease(candidate) else { return nil }
        }

        self.init(
            major: parsed[0],
            minor: parsed[1],
            patch: parsed[2],
            prerelease: candidate
        )
    }

    var description: String {
        let base = "\(major).\(minor).\(patch)"
        guard let prerelease else { return base }
        return "\(base)-\(prerelease)"
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, _):
            // Eine finale Version steht immer über einer Vorabversion.
            return false
        case (_, nil):
            return true
        case (let left?, let right?):
            return comparePrerelease(left, right) < 0
        }
    }

    /// Vergleich zweier Vorabversionen nach SemVer-Regel 11.
    private static func comparePrerelease(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: ".", omittingEmptySubsequences: false)
        let right = rhs.split(separator: ".", omittingEmptySubsequences: false)

        for index in 0..<min(left.count, right.count) {
            let leftPart = String(left[index])
            let rightPart = String(right[index])
            if leftPart == rightPart { continue }

            let leftNumber = numericIdentifier(leftPart)
            let rightNumber = numericIdentifier(rightPart)
            switch (leftNumber, rightNumber) {
            case (let leftValue?, let rightValue?):
                if leftValue == rightValue { continue }
                return leftValue < rightValue ? -1 : 1
            case (_?, nil):
                // Numerische Kennungen stehen unter alphanumerischen.
                return -1
            case (nil, _?):
                return 1
            case (nil, nil):
                return leftPart < rightPart ? -1 : 1
            }
        }

        if left.count == right.count { return 0 }
        return left.count < right.count ? -1 : 1
    }

    private static func numericIdentifier(_ value: String) -> Int? {
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(value)
    }

    private static func isValidPrerelease(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let identifiers = value.split(separator: ".", omittingEmptySubsequences: false)
        guard !identifiers.isEmpty else { return false }

        for identifier in identifiers {
            guard !identifier.isEmpty else { return false }
            for character in identifier {
                let allowed =
                    (character.isASCII && character.isLetter)
                    || (character.isASCII && character.isNumber)
                    || character == "-"
                guard allowed else { return false }
            }
            // Rein numerische Kennungen dürfen keine führende Null haben.
            if identifier.allSatisfy({ $0.isASCII && $0.isNumber }), identifier.count > 1,
                identifier.first == "0"
            {
                return false
            }
        }
        return true
    }
}
