import Foundation

/// Glättet einen Strich, indem eine B-Spline-Kurve durch ihn gelegt wird.
///
/// Der naive Weg – jeden Punkt mit seinen Nachbarn verrechnen – ist genau der
/// Grund, warum geglättete Handschrift oft „zusammengezogen“ aussieht: Ein
/// Tiefpass verschiebt jede Stelle ein Stück nach innen. An engen Bögen und
/// geschlossenen Formen („o“, „a“, „e“) wandert so die halbe Form nach innen;
/// gemessen an einem Kreis wurde aus 26 Punkten Höhe ein Ovals von 11.
///
/// Die Anpassung hier macht das Gegenteil: Sie sucht die Kurve mit *wenigen*
/// Stützstellen, die trotzdem an allen Punkten vorbeikommt. Was zwischen zwei
/// Stützstellen liegt, kann die Kurve gar nicht darstellen – genau dort liegt
/// aber das Zittern (Wellenlänge zwei bis fünf Punkte). Große Formen bleiben,
/// kleines Zittern fällt weg.
///
/// Drei Zutaten halten das stabil:
/// - **Stützweite** (`knotSpacing`): bestimmt, welche Details überleben.
/// - **Biegeenergie**: bestraft die zweite Differenz der Stützpunkte, damit die
///   Kurve zwischen den Stützstellen nicht überschwingt.
/// - **Verankerung der Enden**: der erste und letzte Punkt zählen vielfach, so
///   bleibt der Strich dort, wo der Stift aufgesetzt und abgehoben hat.
///
/// Gerechnet wird pro Abschnitt zwischen zwei erkannten Ecken – ein Knick im
/// „n“ oder „v“ bleibt dadurch scharf.
enum SplineSmoother {
    /// Einstellungen einer Anpassung.
    struct Settings: Equatable {
        /// Abstand der Stützstellen in Seitenpunkten.
        var knotSpacing: Double = 3
        /// Punktabstand der Eingabe in Seitenpunkten.
        var spacing: Double = 0.8
        /// Gewicht der Biegeenergie (0 = nur Daten, groß = sehr steif).
        var bendingWeight: Double = 0.22
        /// Wie stark die beiden Endpunkte verankert werden.
        var pinWeight: Double = 400
        /// Obergrenze der Stützstellen (Rechenzeit: kubisch).
        var maximumControlPoints: Int = 160
    }

    /// Glättet die Punktreihe abschnittsweise zwischen den erkannten Ecken.
    static func smooth(_ points: [Vec2], corners: [Bool], settings: Settings) -> [Vec2] {
        guard points.count >= 6 else { return points }
        var result = points
        for range in PolylineGeometry.segments(points.count, corners: corners) {
            guard range.count >= 6 else { continue }
            let fitted = smoothSegment(Array(points[range]), settings: settings)
            guard fitted.count == range.count else { continue }
            for i in 0..<fitted.count {
                result[range.lowerBound + i] = fitted[i]
            }
        }
        return result
    }

    /// Glättet eine einzelne Punktreihe (ohne Eckenaufteilung).
    static func smoothSegment(_ points: [Vec2], settings: Settings) -> [Vec2] {
        let count = points.count
        guard count >= 6 else { return points }

        let perKnot = max(2, Int((settings.knotSpacing / max(settings.spacing, 0.05)).rounded()))
        let control = min(settings.maximumControlPoints, max(5, count / perKnot + 4))
        let inner = control - 3
        guard inner >= 1 else { return points }

        // Parameter und Segment-Zuordnung: die Datenpunkte werden gleichmäßig
        // über die Stützstellen verteilt.
        var segment = [Int](repeating: 0, count: count)
        var local = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let u = Double(inner) * Double(i) / Double(count - 1)
            let s = min(max(0, Int(u.rounded(.down))), inner - 1)
            segment[i] = s
            local[i] = u - Double(s)
        }

        var normal = [[Double]](repeating: [Double](repeating: 0, count: control), count: control)
        var rightX = [Double](repeating: 0, count: control)
        var rightY = [Double](repeating: 0, count: control)

        for i in 0..<count {
            let weight = (i == 0 || i == count - 1) ? settings.pinWeight : 1
            let weights = basis(local[i])
            let indices = [segment[i], segment[i] + 1, segment[i] + 2, segment[i] + 3]
            for a in 0..<4 {
                let weighted = weights[a] * weight
                rightX[indices[a]] += weighted * points[i].x
                rightY[indices[a]] += weighted * points[i].y
                for c in 0..<4 {
                    normal[indices[a]][indices[c]] += weighted * weights[c]
                }
            }
        }

        // Biegeenergie: zweite Differenz der Stützpunkte.
        let lambda = settings.bendingWeight * 0.09 * Double(count)
        if control >= 3 {
            let pattern = [1.0, -2.0, 1.0]
            for j in 0..<(control - 2) {
                for a in 0..<3 {
                    for c in 0..<3 {
                        normal[j + a][j + c] += lambda * pattern[a] * pattern[c]
                    }
                }
            }
        }

        guard let controlX = LinearAlgebra.solve(normal, rightX) else { return points }
        guard let controlY = LinearAlgebra.solve(normal, rightY) else { return points }
        guard controlX.count == control, controlY.count == control else { return points }

        var result = points
        for i in 0..<count {
            let weights = basis(local[i])
            let indices = [segment[i], segment[i] + 1, segment[i] + 2, segment[i] + 3]
            var x = 0.0
            var y = 0.0
            for a in 0..<4 {
                x += weights[a] * controlX[indices[a]]
                y += weights[a] * controlY[indices[a]]
            }
            let candidate = Vec2(x, y)
            result[i] = InkMath.isFinite(candidate) ? candidate : points[i]
        }
        return result
    }

    /// Kubische B-Spline-Basis für den Parameter `t` in `[0, 1]`.
    ///
    /// Die vier Gewichte summieren sich immer auf eins – die Kurve bleibt
    /// dadurch eine echte Ausgleichsrechnung und nicht nur ein Weichzeichner.
    static func basis(_ t: Double) -> [Double] {
        let squared = t * t
        let cubed = squared * t
        let rest = 1 - t
        return [
            rest * rest * rest / 6,
            (3 * cubed - 6 * squared + 4) / 6,
            (-3 * cubed + 3 * squared + 3 * t + 1) / 6,
            cubed / 6,
        ]
    }
}
