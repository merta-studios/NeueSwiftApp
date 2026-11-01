import Foundation

/// Filterbausteine: Median, Gauß, gleitender Mittelwert.
///
/// Alle Filter sind „randfreundlich“: an den Enden wird der Randwert
/// fortgesetzt, damit Anfangs- und Endpunkt eines Strichs nicht weggezogen
/// werden. Genau die beiden Enden sind es, an denen Buchstaben zusammenstoßen.
enum SignalFilters {
    /// Median über drei Werte – entfernt einzelne Ausreißer (Störspitzen).
    static func median3(_ values: [Double]) -> [Double] {
        guard values.count > 2 else { return values }
        var result = values
        for i in 1..<(values.count - 1) {
            let a = values[i - 1]
            let b = values[i]
            let c = values[i + 1]
            result[i] = max(min(a, b), min(max(a, b), c))
        }
        return result
    }

    /// Median über drei Punkte (je Achse) gegen einzelne Zitter-Ausreißer.
    static func median3(_ points: [Vec2]) -> [Vec2] {
        guard points.count > 2 else { return points }
        var result = points
        for i in 1..<(points.count - 1) {
            let previous = points[i - 1]
            let current = points[i]
            let next = points[i + 1]
            result[i] = Vec2(
                max(min(previous.x, current.x), min(max(previous.x, current.x), next.x)),
                max(min(previous.y, current.y), min(max(previous.y, current.y), next.y))
            )
        }
        return result
    }

    /// Gauß-Filter mit Sigma in Samples.
    static func gaussianSmooth(_ values: [Double], sigma: Double) -> [Double] {
        let count = values.count
        guard count > 2, sigma > 0.05 else { return values }

        let radius = max(1, Int((3 * sigma).rounded()))
        var kernel = [Double](repeating: 0, count: radius + 1)
        var total = 0.0
        for k in 0...radius {
            let weight = exp(-0.5 * pow(Double(k) / sigma, 2))
            kernel[k] = weight
            total += (k == 0) ? weight : 2 * weight
        }
        guard total > 0 else { return values }
        for k in 0...radius {
            kernel[k] /= total
        }

        var result = values
        for i in 0..<count {
            var accumulator = kernel[0] * values[i]
            for k in 1...radius {
                let ahead = values[min(count - 1, i + k)]
                let behind = values[max(0, i - k)]
                accumulator += kernel[k] * (ahead + behind)
            }
            result[i] = accumulator
        }
        return result
    }

    /// Gauß-Filter auf Punkten, getrennt je Achse.
    static func gaussianSmooth(_ points: [Vec2], sigma: Double) -> [Vec2] {
        guard points.count > 2, sigma > 0.05 else { return points }
        var xs = [Double](repeating: 0, count: points.count)
        var ys = [Double](repeating: 0, count: points.count)
        for (index, point) in points.enumerated() {
            xs[index] = point.x
            ys[index] = point.y
        }
        let smoothX = gaussianSmooth(xs, sigma: sigma)
        let smoothY = gaussianSmooth(ys, sigma: sigma)
        var result = points
        for index in points.indices {
            result[index] = Vec2(smoothX[index], smoothY[index])
        }
        return result
    }

    /// Standardabweichung der hochfrequenten Restbewegung.
    ///
    /// Für weißes Rauschen gilt `E[(p[i-1] - 2p[i] + p[i+1])²] = 6σ²`; der Wert
    /// ist damit ein direktes Maß für das Zittern des Schreibers.
    static func highFrequencyEnergy(_ values: [Double]) -> Double {
        guard values.count > 4 else { return 0 }
        var total = 0.0
        var samples = 0
        for i in 1..<(values.count - 1) {
            let second = values[i - 1] - 2 * values[i] + values[i + 1]
            total += second * second
            samples += 1
        }
        guard samples > 0 else { return 0 }
        return (total / Double(samples) / 6).squareRoot()
    }
}
