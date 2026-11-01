import Foundation

/// Anpassung einfacher Formen an eine Punktreihe.
///
/// Handschrift besteht zum großen Teil aus wenigen Grundformen: gerade Striche,
/// Kreisbögen, kleine Haken. Wer diese Formen erkennt und die Linie *sanft*
/// darauf zuzieht, bekommt eine ruhige, gleichmäßige Schrift – ohne die
/// Eigenheiten des Schreibers zu ersetzen.
enum PrimitiveFitting {
    struct LineFit {
        var point: Vec2
        var direction: Vec2
        var rms: Double
    }

    struct CircleFit {
        var center: Vec2
        var radius: Double
        /// Mittlerer radialer Fehler.
        var rms: Double
        /// Insgesamt überstrichener Winkel in Radiant.
        var sweep: Double

        /// Taugt der Fit als Vorlage für einen Handschriftbogen?
        ///
        /// Fast geschlossene Kreise und riesige Bögen werden ausgelassen: Ein
        /// Buchstabe ist selten ein perfekter Kreis, und ein sehr großer Radius
        /// bedeutet nur, dass die Linie fast gerade ist.
        func fitsArc(_ tolerance: Double) -> Bool {
            rms < tolerance && sweep > 1.4 && sweep < 6.1 && radius < 400 && radius > 2
        }
    }

    /// Hauptachse über die Kovarianz (Gesamtmethode der kleinsten Quadrate).
    static func fitLine(_ points: [Vec2]) -> LineFit? {
        guard points.count >= 2 else { return nil }

        var sumX = 0.0
        var sumY = 0.0
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        let count = Double(points.count)
        let mean = Vec2(sumX / count, sumY / count)

        var sxx = 0.0
        var sxy = 0.0
        var syy = 0.0
        for point in points {
            let delta = point - mean
            sxx += delta.x * delta.x
            sxy += delta.x * delta.y
            syy += delta.y * delta.y
        }
        sxx /= count
        sxy /= count
        syy /= count

        let theta = 0.5 * atan2(2 * sxy, sxx - syy)
        let direction = Vec2(cos(theta), sin(theta))

        var error = 0.0
        for point in points {
            let delta = point - mean
            let perpendicular = delta - direction * delta.dot(direction)
            error += perpendicular.lengthSquared
        }
        let rms = (error / count).squareRoot()
        guard rms.isFinite else { return nil }
        return LineFit(point: mean, direction: direction, rms: rms)
    }

    /// Kreis durch die Punkte (Kåsa). Die Punkte werden vorher um den
    /// Schwerpunkt gelegt, sonst wird das kleine Gleichungssystem ungenau.
    static func fitCircle(_ points: [Vec2]) -> CircleFit? {
        guard points.count >= 5 else { return nil }

        var sumX = 0.0
        var sumY = 0.0
        for point in points {
            sumX += point.x
            sumY += point.y
        }
        let count = Double(points.count)
        let mean = Vec2(sumX / count, sumY / count)

        var matrix = [[Double]](repeating: [0, 0, 0], count: 3)
        var rhs = [Double](repeating: 0, count: 3)
        for point in points {
            let delta = point - mean
            let z = delta.lengthSquared
            let row = [delta.x, delta.y, 1.0]
            for i in 0..<3 {
                rhs[i] += row[i] * -z
                for j in 0..<3 {
                    matrix[i][j] += row[i] * row[j]
                }
            }
        }

        guard let solution = LinearAlgebra.solve(matrix, rhs) else { return nil }
        let d = solution[0]
        let e = solution[1]
        let f = solution[2]
        let localCenter = Vec2(-d / 2, -e / 2)
        let radiusSquared = localCenter.lengthSquared - f
        guard radiusSquared > 1e-9, radiusSquared.isFinite else { return nil }
        let radius = radiusSquared.squareRoot()
        guard radius.isFinite else { return nil }

        let center = localCenter + mean
        var error = 0.0
        for point in points {
            let difference = (point - center).length - radius
            error += difference * difference
        }

        var sweep = 0.0
        for i in 1..<points.count {
            let first = points[i - 1] - center
            let second = points[i] - center
            sweep += abs(atan2(first.cross(second), first.dot(second)))
        }

        return CircleFit(
            center: center,
            radius: radius,
            rms: (error / count).squareRoot(),
            sweep: sweep
        )
    }
}
