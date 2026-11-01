import Foundation

/// Entfernt winzige Überschwinger am Strichanfang und -ende.
///
/// Wer schnell schreibt, zieht am Ende eines Strichs oft noch ein kurzes Stück
/// zurück („Schnipser“). Solche Häkchen von einem Punkt Länge sind fast immer
/// unbeabsichtigt und machen die Schrift unsauber. Echte Häkchen der Handschrift
/// (etwa beim „r“ oder „c“) sind länger und werden nicht angefasst: Der Filter
/// greift nur, wenn sich die Richtung auf kürzestem Weg fast umkehrt.
enum TerminalTrimmer {
    /// - Parameters:
    ///   - maxHookLength: längste Länge eines Endstücks, das als Überschwinger gilt.
    ///   - minReversal: ab diesem Richtungswechsel (Radiant) gilt es als Umkehr.
    ///   - minStrokeLength: sehr kurze Striche bleiben unverändert.
    ///   - maxIterations: höchstens so viele Punkte werden je Ende entfernt.
    static func trim(
        _ points: [InkPoint],
        maxHookLength: Double = 2.4,
        minReversal: Double = 2.2,
        minStrokeLength: Double = 12,
        maxIterations: Int = 2
    ) -> [InkPoint] {
        guard points.count > 9 else { return points }
        let positions = points.map { $0.position }
        guard PolylineGeometry.totalLength(positions) > minStrokeLength else { return points }

        var result = points
        for _ in 0..<max(1, maxIterations) {
            let trimmed = trimEnd(result, maxHookLength: maxHookLength, minReversal: minReversal)
            if trimmed.count == result.count { break }
            result = trimmed
        }
        for _ in 0..<max(1, maxIterations) {
            let trimmed = trimStart(
                result, maxHookLength: maxHookLength, minReversal: minReversal
            )
            if trimmed.count == result.count { break }
            result = trimmed
        }
        guard result.count >= 4 else { return points }
        return result
    }

    private static func trimEnd(
        _ points: [InkPoint], maxHookLength: Double, minReversal: Double
    ) -> [InkPoint] {
        let count = points.count
        guard count > 6 else { return points }
        let tail = points[count - 1].position - points[count - 2].position
        let main = points[count - 3].position - points[count - 4].position
        guard tail.length > 1e-6, main.length > 1e-6 else { return points }
        guard tail.length <= maxHookLength else { return points }
        let turn = abs(atan2(main.cross(tail), main.dot(tail)))
        guard turn > minReversal else { return points }
        return Array(points[0..<(count - 1)])
    }

    private static func trimStart(
        _ points: [InkPoint], maxHookLength: Double, minReversal: Double
    ) -> [InkPoint] {
        let count = points.count
        guard count > 6 else { return points }
        let head = points[0].position - points[1].position
        let main = points[3].position - points[2].position
        guard head.length > 1e-6, main.length > 1e-6 else { return points }
        guard head.length <= maxHookLength else { return points }
        let turn = abs(atan2(main.cross(head), main.dot(head)))
        guard turn > minReversal else { return points }
        return Array(points[1..<count])
    }
}
