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
    file: String = #filePath,
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
    file: String = #filePath,
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
    file: String = #filePath,
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
expectEqual(
    SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: "").description,
    "1.0.0",
    "Leere Vorabversion erscheint nicht in der Beschreibung"
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

// MARK: - Hilfen für die Tests der Tinten-Engine

/// Deterministischer Zufall (LCG) – Tests dürfen nicht von Zufall abhängen.
struct TestRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
    }

    /// Wert in -1 … 1.
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let bits = (state >> 11) & 0xFFFFFFFF
        return Double(bits) / Double(0xFFFFFFFF) * 2 - 1
    }
}

/// Mittlere zweite Differenz – ein direktes Maß für „zittrige“ Linien.
private func roughness(_ points: [Vec2]) -> Double {
    guard points.count > 2 else { return 0 }
    var total = 0.0
    for i in 1..<(points.count - 1) {
        let second = points[i - 1] - points[i] * 2 + points[i + 1]
        total += second.length
    }
    return total / Double(points.count - 2)
}

/// Mittlerer Abstand zweier gleich langer Punktreihen.
private func meanDistance(_ first: [Vec2], _ second: [Vec2]) -> Double {
    let count = min(first.count, second.count)
    guard count > 0 else { return 0 }
    var total = 0.0
    for i in 0..<count {
        total += first[i].distance(to: second[i])
    }
    return total / Double(count)
}

/// Mittlerer Abstand einer Punktreihe zu einem Referenzweg.
private func meanDistanceToPath(_ points: [Vec2], path: [Vec2]) -> Double {
    guard !points.isEmpty, path.count > 1 else { return 0 }
    var total = 0.0
    for point in points {
        if let hit = PolylineGeometry.closestPointOnPolyline(point, points: path) {
            total += hit.distance
        }
    }
    return total / Double(points.count)
}

/// Rohpunkte einer „schnell und schmierig“ geschriebenen Wellenlinie.
///
/// `jitter` ist die Zitteramplitude in Seitenpunkten, `pressure` der mittlere
/// Stiftdruck. Die Zeitstempel entsprechen schnellem Schreiben (240 Hz).
private func sloppyInputs(
    samples: Int,
    jitter: Double,
    seed: UInt64,
    origin: Vec2 = Vec2(40, 80),
    pressure: Double = 0.3
) -> [InkInput] {
    var random = TestRandom(seed: seed)
    var inputs: [InkInput] = []
    inputs.reserveCapacity(samples)
    for i in 0..<samples {
        let t = Double(i) / Double(max(1, samples - 1))
        let base = Vec2(
            origin.x + 150 * t,
            origin.y + 26 * sin(t * 3.1) - 10 * t
        )
        let noise = Vec2(random.next() * jitter, random.next() * jitter)
        let wobble = random.next() * 0.08
        inputs.append(
            InkInput(
                position: base + noise,
                pressure: InkMath.clamp(pressure + wobble, 0, 1),
                hasPressure: true,
                altitude: 1.15,
                time: t * 0.5
            )
        )
    }
    return inputs
}

// MARK: - Vektoren und elementare Mathematik

expectEqual(Vec2(3, 4).length, 5, "Länge eines Vektors")
expect(abs(Vec2(3, 4).normalized.length - 1) < 1e-12, "Einheitsvektor hat Länge 1")
expectEqual(Vec2.zero.normalized, Vec2.zero, "Nullvektor bleibt Nullvektor")
expect(abs(Vec2(1, 0).rotated(by: Double.pi / 2).x) < 1e-12, "Drehung um 90° (x)")
expect(abs(Vec2(1, 0).rotated(by: Double.pi / 2).y - 1) < 1e-12, "Drehung um 90° (y)")
expectEqual(Vec2(1, 2).dot(Vec2(3, 4)), 11, "Skalarprodukt")
expectEqual(Vec2(1, 0).cross(Vec2(0, 1)), 1, "Kreuzprodukt")
expectEqual(Vec2(1, 0).perpendicular, Vec2(0, 1), "Senkrechte")
expectEqual(Vec2.lerp(Vec2(0, 0), Vec2(10, 20), 0.5), Vec2(5, 10), "Interpolation")
expectEqual(Vec2.atAngle(0, length: 2), Vec2(2, 0), "Vektor aus Winkel")
expectEqual(InkMath.clamp(5, 0, 1), 1, "clamp nach oben")
expectEqual(InkMath.clamp(-5, 0, 1), 0, "clamp nach unten")
expect(abs(InkMath.wrap(3 * Double.pi) - Double.pi) < 1e-9, "Winkel normalisieren")
expect(abs(InkMath.wrap(-3 * Double.pi) - Double.pi) < 1e-9, "Winkel normalisieren (negativ)")
expect(abs(InkMath.easeOut(0)) < 1e-12, "Ease-out startet bei 0")
expect(abs(InkMath.easeOut(1) - 1) < 1e-12, "Ease-out endet bei 1")
expect(abs(InkMath.smoothstep(0, 1, 0.5) - 0.5) < 1e-12, "Smoothstep in der Mitte")

let unwrapped = InkMath.unwrap([3.0, -3.0, 3.0])
expectEqual(unwrapped.count, 3, "Entrollen behält die Länge")
expect(unwrapped[1] > 3, "Entrollen macht aus dem Sprung einen stetigen Verlauf")

if let solution = LinearAlgebra.solve([[2, 1], [1, 3]], [5, 10]) {
    expect(abs(solution[0] - 1) < 1e-9, "2×2-System: x")
    expect(abs(solution[1] - 3) < 1e-9, "2×2-System: y")
} else {
    expect(false, "2×2-System ist lösbar")
}
expectNil(LinearAlgebra.solve([[1, 2], [2, 4]], [1, 2]), "Singuläres System hat keine Lösung")

if let coefficients = LinearAlgebra.leastSquares(
    rows: [[1, 0], [1, 1], [1, 2], [1, 3]], targets: [1, 3, 5, 7], ridge: 0
) {
    expect(abs(coefficients[0] - 1) < 1e-6, "Ausgleichsgerade: Achsenabschnitt")
    expect(abs(coefficients[1] - 2) < 1e-6, "Ausgleichsgerade: Steigung")
} else {
    expect(false, "Ausgleichsgerade ist berechenbar")
}

// MARK: - Bogenlänge und Resampling

let straightLine = (0...20).map { Vec2(Double($0) * 0.5, 0) }
expectEqual(PolylineGeometry.totalLength(straightLine), 10, "Bogenlänge einer Geraden")
expectEqual(PolylineGeometry.cumulativeLengths(straightLine).last ?? -1, 10, "Kumulierte Länge")
let coarseLengths = [0.0, 1, 2, 3, 4, 5, 6]
expectEqual(PolylineGeometry.index(atLength: 5, lengths: coarseLengths), 5, "Index zur Länge")

let bent = InkTrace(points: [Vec2(0, 0), Vec2(3, 1), Vec2(3, 9)], altitudes: [1, 1, 1])
let resampledTrace = PolylineGeometry.resample(bent, spacing: 0.5)
expect(resampledTrace.count > 15, "Resampling erzeugt eine dichte Reihe")
expect(resampledTrace.count < 30, "Resampling erzeugt nicht unnötig viele Punkte")
// Der Abstand wird auf einer Geraden geprüft: In einem Knick ist der
// geradlinige Abstand zweier Punkte kleiner als ihr Bogenabstand.
let straightTrace = InkTrace(points: (0...12).map { Vec2(Double($0), 0) })
let straightResampled = PolylineGeometry.resample(straightTrace, spacing: 0.5)
var uniformSpacing = true
for i in 1..<(straightResampled.count - 1) {
    let step = straightResampled.points[i].distance(to: straightResampled.points[i - 1])
    if abs(step - 0.5) > 1e-6 { uniformSpacing = false }
}
expect(uniformSpacing, "Resampling hält den Punktabstand ein")
expectEqual(resampledTrace.points[0], Vec2(0, 0), "Resampling behält den Startpunkt")
expect(
    (resampledTrace.points.last ?? Vec2.zero).distance(to: Vec2(3, 9)) < 1e-9,
    "Resampling behält den Endpunkt"
)
expect(
    resampledTrace.pressures.count == resampledTrace.points.count,
    "Begleitwerte bleiben synchron"
)

// Die Gerade reicht von x = 0 bis x = 10, bei Bogenlänge 5 liegt also x = 5.
let pointAtHalf = PolylineGeometry.point(atLength: 5, points: straightLine)
expect(abs(pointAtHalf.x - 5) < 1e-9, "Punkt bei halber Bogenlänge")

let foot = PolylineGeometry.closestPoint(onSegment: Vec2(0, 0), Vec2(10, 0), to: Vec2(4, 3))
expect(abs(foot.point.x - 4) < 1e-9 && abs(foot.point.y) < 1e-12, "Fußpunkt auf der Strecke")

let simplifiedLine = PolylineGeometry.simplified(straightLine, epsilon: 0.1)
expectEqual(simplifiedLine.count, 2, "Douglas-Peucker reduziert eine Gerade auf zwei Punkte")

if let nearest = PolylineGeometry.closestPointOnPolyline(Vec2(5, 4), points: straightLine) {
    expect(abs(nearest.distance - 4) < 1e-9, "Abstand zu einer Polylinie")
} else {
    expect(false, "Abstand zu einer Polylinie ist bestimmbar")
}

// MARK: - Filter

let constantValues = [Double](repeating: 3, count: 24)
let smoothedConstant = SignalFilters.gaussianSmooth(constantValues, sigma: 2)
expect(abs((smoothedConstant.max() ?? 0) - 3) < 1e-9, "Gauß verändert konstante Werte nicht")
expect(abs((smoothedConstant.min() ?? 0) - 3) < 1e-9, "Gauß verändert konstante Werte nicht (min)")

let spiked = [0.0, 0.0, 9.0, 0.0, 0.0]
expectEqual(SignalFilters.median3(spiked)[2], 0, "Median entfernt eine einzelne Spitze")
expectEqual(SignalFilters.median3(spiked)[0], 0, "Median lässt den Rand in Ruhe")

let noisyRow = [0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0]
let smoothedRow = SignalFilters.gaussianSmooth(noisyRow, sigma: 1.5)
expect(
    SignalFilters.highFrequencyEnergy(smoothedRow)
        < SignalFilters.highFrequencyEnergy(noisyRow),
    "Gauß senkt die hochfrequente Energie"
)
expect(
    SignalFilters.highFrequencyEnergy([Double](repeating: 0, count: 10)) < 1e-12,
    "Eine Gerade hat keine hochfrequente Energie"
)

// MARK: - Spline-Glättung

var splineRandom = TestRandom(seed: 5)
let jitteryLine = (0..<80).map { i -> Vec2 in
    Vec2(Double(i) * 0.8, splineRandom.next() * 0.9)
}
let noCorners = [Bool](repeating: false, count: jitteryLine.count)
var lineSettings = SplineSmoother.Settings()
lineSettings.knotSpacing = 3
lineSettings.spacing = 0.8
let splineSmoothed = SplineSmoother.smooth(
    jitteryLine, corners: noCorners, settings: lineSettings
)
expect(
    splineSmoothed[0].distance(to: jitteryLine[0]) < 0.05,
    "Spline-Glättung hält den Startpunkt fest"
)
expect(
    splineSmoothed[splineSmoothed.count - 1]
        .distance(to: jitteryLine[jitteryLine.count - 1]) < 0.05,
    "Spline-Glättung hält den Endpunkt fest"
)
expect(
    roughness(splineSmoothed) < roughness(jitteryLine) * 0.5,
    "Spline-Glättung halbiert das Zittern "
        + "(\(roughness(jitteryLine)) → \(roughness(splineSmoothed)))"
)
expect(
    abs(PolylineGeometry.totalLength(splineSmoothed) - PolylineGeometry.totalLength(jitteryLine))
        < 0.6 * PolylineGeometry.totalLength(jitteryLine),
    "Spline-Glättung verändert die Länge nicht grob"
)
expect(
    meanDistance(splineSmoothed, jitteryLine) < 1.2,
    "Spline-Glättung bleibt an ihrer Linie "
        + "(Abweichung \(meanDistance(splineSmoothed, jitteryLine)))"
)

// Eine Gerade muss eine Gerade bleiben – auch mit Störungen darauf.
let straightRamp = (0..<90).map { Vec2(Double($0) * 0.8, 10 + Double($0) * 0.2) }
let rampSmoothed = SplineSmoother.smooth(straightRamp, corners: noCorners, settings: lineSettings)
var rampDeviation = 0.0
for i in 0..<straightRamp.count {
    rampDeviation = max(rampDeviation, rampSmoothed[i].distance(to: straightRamp[i]))
}
expect(rampDeviation < 1e-6, "Eine Gerade bleibt eine Gerade (Abweichung \(rampDeviation))")

// Der Kreis ist der harte Fall: Ein Tiefpass zieht ihn zusammen, die
// Spline-Anpassung darf das nicht.
let splineCircle = (0..<120).map { i -> Vec2 in
    let angle = Double(i) / 119 * 2 * Double.pi
    return Vec2(60 + 26 * cos(angle), 60 + 26 * sin(angle))
}
let splineCircleCorners = [Bool](repeating: false, count: splineCircle.count)
let circleSmoothed = SplineSmoother.smooth(
    splineCircle, corners: splineCircleCorners, settings: lineSettings
)
func bounds(_ points: [Vec2]) -> (width: Double, height: Double) {
    var minX = points[0].x
    var maxX = points[0].x
    var minY = points[0].y
    var maxY = points[0].y
    for point in points {
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
    }
    return (maxX - minX, maxY - minY)
}
let circleBefore = bounds(splineCircle)
let circleAfter = bounds(circleSmoothed)
let widthKept = abs(circleAfter.width - circleBefore.width) < 1.5
let heightKept = abs(circleAfter.height - circleBefore.height) < 1.5
expect(widthKept && heightKept, "Der Kreis bleibt ein Kreis (\(circleBefore) → \(circleAfter))")

// Ein Knick bleibt scharf: die Ecke sitzt danach noch am Knick.
var vShape: [Vec2] = []
for i in 0...30 {
    vShape.append(Vec2(Double(i) * 0.8, Double(i) * 0.4))
}
for i in 1...30 {
    vShape.append(Vec2(24 - Double(i) * 0.8, 12 + Double(i) * 0.4))
}
let vCorners = CornerDetector.detect(points: vShape, spacing: 0.8)
let vSmoothed = SplineSmoother.smooth(vShape, corners: vCorners, settings: lineSettings)
let vIndices = CornerDetector.cornerIndices(of: vCorners)
if let cornerIndex = vIndices.first {
    expect(
        vSmoothed[cornerIndex].distance(to: vShape[cornerIndex]) < 1e-6,
        "Die Ecke bleibt beim Glätten an ihrem Platz"
    )
}

let cornerMask = [false, false, false, true, false, false, false, false, false]
let cornerRange = PolylineGeometry.segments(9, corners: cornerMask)
expectEqual(cornerRange.count, 2, "Ecken zerlegen den Strich in zwei Abschnitte")
expectEqual(cornerRange[0].upperBound, 4, "Der Eckpunkt gehört zum ersten Abschnitt")
expectEqual(cornerRange[1].lowerBound, 3, "Der Eckpunkt gehört auch zum zweiten Abschnitt")

// MARK: - Ecken

var cornerShape: [Vec2] = []
for i in 0...30 {
    cornerShape.append(Vec2(Double(i) * 0.8, 0))
}
for i in 1...30 {
    cornerShape.append(Vec2(24, Double(i) * 0.8))
}
let cornerFlags = CornerDetector.detect(points: cornerShape, spacing: 0.8)
let detectedCorners = CornerDetector.cornerIndices(of: cornerFlags)
expect(!detectedCorners.isEmpty, "L-Form hat eine Ecke")
if let firstCorner = detectedCorners.first {
    expect(abs(firstCorner - 30) <= 3, "Ecke liegt am Knick (Index \(firstCorner) statt 30)")
}
expect(detectedCorners.count <= 2, "Ein Knick ergibt nicht viele Ecken")

let straightFlags = CornerDetector.detect(
    points: (0...40).map { Vec2(Double($0) * 0.8, 0) }, spacing: 0.8
)
expect(!straightFlags.contains(true), "Eine Gerade hat keine Ecke")

let arcPoints = (0...60).map { i -> Vec2 in
    let angle = Double(i) * 0.05
    return Vec2(40 + 20 * cos(angle), 40 + 20 * sin(angle))
}
let arcFlags = CornerDetector.detect(points: arcPoints, spacing: 0.8)
expect(!arcFlags.contains(true), "Ein ruhiger Bogen hat keine Ecke")

// MARK: - Formanpassung

var snapRandom = TestRandom(seed: 21)
let wonkyLine = (0..<60).map { i -> Vec2 in
    Vec2(Double(i) * 0.8, snapRandom.next() * 0.5)
}
let snappedLine = ShapeSnapping.snap(wonkyLine, tolerance: 1.2)
let beforeFit = PrimitiveFitting.fitLine(wonkyLine)
let afterFit = PrimitiveFitting.fitLine(snappedLine)
expect(beforeFit != nil && afterFit != nil, "Geradenfit ist möglich")
if let beforeFit, let afterFit {
    expect(afterFit.rms < beforeFit.rms * 0.5, "Formanpassung macht die Linie gerader")
}

let circlePoints = (0..<80).map { i -> Vec2 in
    let angle = Double(i) / 79 * 5.0
    return Vec2(50 + 12 * cos(angle), 60 + 12 * sin(angle))
}
let snappedCircle = ShapeSnapping.snap(circlePoints, tolerance: 1.0)
if let circleFit = PrimitiveFitting.fitCircle(snappedCircle) {
    expect(abs(circleFit.radius - 12) < 0.8, "Ein Kreis bleibt ein Kreis")
    expect(circleFit.sweep > 4, "Der überstrichene Winkel wird erkannt")
} else {
    expect(false, "Kreisfit ist möglich")
}
expectNil(
    PrimitiveFitting.fitCircle([Vec2(0, 0), Vec2(1, 0), Vec2(2, 0)]),
    "Zu wenige Punkte für einen Kreis"
)

// MARK: - Überschwinger an den Enden

var hookedStroke: [InkPoint] = []
for i in 0...40 {
    hookedStroke.append(InkPoint(position: Vec2(10 + Double(i) * 0.8, 50), width: 2))
}
hookedStroke.append(InkPoint(position: Vec2(40.9, 49.6), width: 2))
hookedStroke.append(InkPoint(position: Vec2(39.9, 49.4), width: 2))
let trimmedStroke = TerminalTrimmer.trim(hookedStroke)
expect(
    trimmedStroke.count < hookedStroke.count,
    "Der Schnipser am Ende wird entfernt (\(hookedStroke.count) → \(trimmedStroke.count))"
)
let plainStroke = (0...40).map { InkPoint(position: Vec2(Double($0) * 0.8, 20), width: 2) }
expectEqual(
    TerminalTrimmer.trim(plainStroke).count,
    plainStroke.count,
    "Eine saubere Linie wird nicht gekürzt"
)

// MARK: - Verbindungen zwischen Strichen

let neighborStroke = (0..<24).map { InkPoint(position: Vec2(50 + Double($0) * 0.8, 100), width: 2) }
var approaching: [InkPoint] = []
for i in 0...24 {
    let x = 30 + Double(i) * 0.8
    let y = 88 + Double(i) * 0.5
    approaching.append(InkPoint(position: Vec2(x, y), width: 2))
}
approaching.append(InkPoint(position: Vec2(49.4, 100.3), width: 2))

let weldResult = JunctionWelder.weld(approaching, to: [neighborStroke], radius: 2.5)
expect(weldResult.weldedEnd, "Ein nahes Ende wird verbunden")
expect(
    (weldResult.points.last?.position ?? Vec2.zero).distance(to: Vec2(50, 100)) < 1e-9,
    "Das Ende sitzt danach genau auf dem Nachbarstrich"
)
expect(!weldResult.weldedStart, "Ein fernes Ende bleibt unverbunden")

let farResult = JunctionWelder.weld(approaching, to: [neighborStroke], radius: 0.1)
expect(!farResult.weldedEnd, "Ohne Nähe wird nicht verbunden")
expectEqual(farResult.points.count, approaching.count, "Verbinden ändert die Punktzahl nicht")

// MARK: - Gelerntes Schreibprofil

var style = WritingStyle()
expect(style.confidence < 0.2, "Ein frisches Profil ist unsicher")
expect(
    style.knotSpacing >= 2.5 && style.knotSpacing <= 3.5,
    "Stützweite der Glättung bleibt im Rahmen"
)

let lightTouch = style.width(pressure: 0.1, hasPressure: true, speed: 200, altitude: 1.5)
let firmTouch = style.width(pressure: 0.4, hasPressure: true, speed: 200, altitude: 1.5)
expect(firmTouch > lightTouch, "Mehr Druck ergibt einen breiteren Strich")

let slowMove = style.width(pressure: 0.3, hasPressure: true, speed: 30, altitude: 1.5)
let fastMove = style.width(pressure: 0.3, hasPressure: true, speed: 1200, altitude: 1.5)
expect(slowMove > fastMove, "Schnelles Schreiben ergibt einen dünneren Strich")

let tilted = style.width(pressure: 0.3, hasPressure: true, speed: 200, altitude: 0.4)
let upright = style.width(pressure: 0.3, hasPressure: true, speed: 200, altitude: 1.55)
expect(tilted > upright, "Ein schräg gehaltener Stift schreibt breiter")

let noPressureWidth = style.width(pressure: 0, hasPressure: false, speed: 200, altitude: 1.5)
expect(noPressureWidth > 0.5, "Ohne Druckangabe bleibt der Strich sichtbar")

for _ in 0..<20 {
    style.observe(tremor: 0.45, slant: 0.4, peakPressure: 0.5, hasPressure: true, medianSpeed: 700)
}
expectEqual(style.strokeCount, 20, "Profil zählt die Striche")
expect(style.confidence > 0.99, "Nach vielen Strichen ist das Profil sicher")
expect(style.slant > 0.2, "Das Profil übernimmt die beobachtete Neigung")
expect(style.tremor > 0.3, "Das Profil merkt sich stärkeres Zittern")
expect(style.knotSpacing > 3, "Starkes Zittern führt zu weiteren Stützstellen")

var resetStyle = style
resetStyle.reset()
expectEqual(resetStyle.strokeCount, 0, "Zurücksetzen löscht die Strichzahl")

// MARK: - Aufbereitung eines Strichs

let sloppy = sloppyInputs(samples: 180, jitter: 0.55, seed: 2024)
let engine = InkEngine()
let preview = engine.preview(sloppy)
// Die Vorschau wird auf dieselbe Abtastung gebracht wie die Endfassung –
// nur so kann der Morph Punkt für Punkt überblenden.
let expectedPreview = PolylineGeometry.resample(
    StrokeBeautifier().prepare(sloppy, style: WritingStyle()).trace,
    spacing: 0.8
)
expectEqual(
    preview.count,
    expectedPreview.count,
    "Die Vorschau hat dieselbe Abtastung wie die Endfassung"
)
expect(
    preview.allSatisfy { $0.width > 0.4 && $0.width < 7 },
    "Vorschau-Breiten liegen im sinnvollen Bereich"
)

let beautiful = engine.finish(sloppy)
expect(beautiful.count > 20, "Der fertige Strich hat genug Punkte")
expect(beautiful.count < 1500, "Der fertige Strich bleibt performant")
expect(
    beautiful.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite },
    "Keine ungültigen Koordinaten"
)
expect(
    beautiful.allSatisfy { $0.width >= 0.4 && $0.width <= 6.6 },
    "Breiten bleiben im Rahmen"
)

let beautifiedPositions = beautiful.map { $0.position }
let prepared = StrokeBeautifier().prepare(sloppy, style: WritingStyle())
let rawResampled = PolylineGeometry.resample(prepared.trace, spacing: 0.8).points
expect(
    roughness(beautifiedPositions) < roughness(rawResampled) * 0.6,
    "Die aufbereitete Linie ist deutlich ruhiger "
        + "(\(roughness(rawResampled)) → \(roughness(beautifiedPositions)))"
)
expect(
    meanDistanceToPath(beautifiedPositions, path: rawResampled) < 2.5,
    "Die aufbereitete Linie bleibt an ihrem Platz"
)
expect(
    (beautiful.first?.position ?? Vec2.zero).distance(to: sloppy[0].position) < 4,
    "Der Strich beginnt weiterhin dort, wo der Stift aufgesetzt hat"
)
expect(
    (beautiful.last?.position ?? Vec2.zero).distance(to: sloppy[sloppy.count - 1].position) < 6,
    "Der Strich endet weiterhin dort, wo der Stift abgehoben hat"
)
expectEqual(engine.finishedStrokes, 1, "Die Engine zählt fertige Striche")
expectEqual(engine.style.strokeCount, 1, "Das Profil hat den Strich übernommen")

// Mehrere Striche: das Profil wird sicherer und bleibt im Rahmen.
for index in 0..<8 {
    _ = engine.finish(sloppyInputs(samples: 120, jitter: 0.5, seed: UInt64(100 + index)))
}
expectEqual(engine.style.strokeCount, 9, "Alle Striche landen im Profil")
expect(engine.style.confidence > 0.85, "Das Profil ist nach neun Strichen belastbar")
expect(
    engine.style.tremor.isFinite && engine.style.knotSpacing >= 2.5,
    "Die gelernte Stützweite bleibt beherrschbar"
)

// Ein perfekt gerader Strich muss gerade bleiben.
let perfectlyStraight = (0..<80).map { i -> InkInput in
    InkInput(
        position: Vec2(20 + Double(i) * 1.2, 200),
        pressure: 0.3,
        hasPressure: true,
        altitude: 1.5,
        time: Double(i) * 0.01
    )
}
let straightResult = InkEngine().finish(perfectlyStraight)
let straightFit = PrimitiveFitting.fitLine(straightResult.map { $0.position })
if let straightFit {
    expect(straightFit.rms < 0.15, "Ein gerader Strich bleibt gerade (rms \(straightFit.rms))")
} else {
    expect(false, "Geradenfit des geraden Strichs ist möglich")
}

// Randfälle: nichts darf abstürzen.
let emptyEngine = InkEngine()
expect(emptyEngine.preview([]).isEmpty, "Leere Eingabe ergibt keine Vorschau")
expect(emptyEngine.finish([]).isEmpty, "Leere Eingabe ergibt keinen Strich")
let singleDot = emptyEngine.finish([InkInput(position: Vec2(5, 5))])
expectEqual(singleDot.count, 1, "Ein Punkt ergibt einen Tupfer")
expectEqual(
    emptyEngine.finish([
        InkInput(position: Vec2(5, 5), time: 0),
        InkInput(position: Vec2(5, 5), time: 0.01),
    ]).count,
    1,
    "Doppelte Punkte ergeben einen Tupfer"
)
expect(
    emptyEngine.finish([
        InkInput(position: Vec2(Double.nan, 3), time: 0),
        InkInput(position: Vec2(1, 2), time: 0.01),
        InkInput(position: Vec2(3, 4), time: 0.02),
    ]).allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite },
    "Ungültige Koordinaten werden verworfen"
)
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
