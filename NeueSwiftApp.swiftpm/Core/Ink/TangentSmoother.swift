import Foundation

/// Glättung im Winkelbereich – das Herzstück der Strichaufbereitung.
///
/// Statt Punkte zu mitteln (das macht Linien kurz und „gummig“) wird hier die
/// Tangentenrichtung entlang der Bogenlänge gefiltert und daraus die Linie neu
/// aufgebaut. Das hat drei angenehme Eigenschaften:
///
/// * Die Bogenlänge bleibt erhalten – ein Strich wird nicht kürzer, wenn er
///   stark geglättet wird.
/// * Zittern ist eine hochfrequente Störung der Richtung und verschwindet
///   dadurch fast vollständig, während der große Bogen exakt erhalten bleibt.
/// * Ecken bleiben Ecken: An einer erkannten Ecke endet der geglättete Abschnitt,
///   die Richtung wird dort also nicht „rundgebügelt“.
enum TangentSmoother {
    /// - Parameters:
    ///   - corners: Markierung echter Ecken (gleiche Länge wie `points`).
    ///   - sigma: Glättungsstärke in Seitenpunkten (gelernt aus dem Zittern).
    ///   - spacing: Punktabstand der Reihe.
    static func smooth(
        _ points: [Vec2],
        corners: [Bool],
        sigma: Double,
        spacing: Double
    ) -> [Vec2] {
        guard points.count >= 3 else { return points }
        var result = points
        for range in segments(points.count, corners: corners) {
            let slice = Array(points[range])
            let smoothed = smoothSegment(slice, sigma: sigma, spacing: spacing)
            guard smoothed.count == slice.count else { continue }
            for i in 0..<smoothed.count {
                result[range.lowerBound + i] = smoothed[i]
            }
        }
        return result
    }

    /// Zerlegt die Reihe an den Ecken. Die Eckpunkte gehören zu beiden
    /// Abschnitten, damit die Linie dort zusammenhängt.
    static func segments(_ count: Int, corners: [Bool]) -> [ClosedRange<Int>] {
        guard count >= 2 else { return [] }
        var result: [ClosedRange<Int>] = []
        var start = 0
        for i in 1..<(count - 1) where i < corners.count && corners[i] {
            if i > start { result.append(start...i) }
            start = i
        }
        if count - 1 > start {
            result.append(start...(count - 1))
        }
        if result.isEmpty {
            result.append(0...(count - 1))
        }
        return result
    }

    static func smoothSegment(_ slice: [Vec2], sigma: Double, spacing: Double) -> [Vec2] {
        let count = slice.count
        guard count >= 3 else { return slice }

        var angles = [Double](repeating: 0, count: count)
        for i in 0..<count {
            let behind = slice[i == 0 ? 0 : i - 1]
            let ahead = slice[i == count - 1 ? count - 1 : i + 1]
            let delta = ahead - behind
            angles[i] = delta.length > 1e-9 ? atan2(delta.y, delta.x) : 0
        }

        let unwrapped = InkMath.unwrap(angles)
        let sigmaSamples = InkMath.clamp(
            sigma / max(spacing, 0.05), 0.7, 0.3 * Double(count)
        )
        let filtered = SignalFilters.gaussianSmooth(unwrapped, sigma: sigmaSamples)

        var rebuilt = [Vec2](repeating: Vec2.zero, count: count)
        rebuilt[0] = slice[0]
        for i in 1..<count {
            let step = (slice[i] - slice[i - 1]).length
            let heading = 0.5 * (filtered[i - 1] + filtered[i])
            rebuilt[i] = rebuilt[i - 1] + Vec2.atAngle(heading, length: step)
        }

        // Der Neuaufbau weicht an den Enden minimal ab. Diese Abweichung wird
        // linear verteilt zurückgenommen, damit Anfangs- und Endpunkt exakt
        // dort bleiben, wo der Stift sie gesetzt hat.
        let startDrift = slice[0] - rebuilt[0]
        let endDrift = slice[count - 1] - rebuilt[count - 1]
        for i in 0..<count {
            let t = Double(i) / Double(count - 1)
            rebuilt[i] += startDrift * (1 - t) + endDrift * t
        }

        for point in rebuilt where !InkMath.isFinite(point) {
            return slice
        }
        return rebuilt
    }
}
