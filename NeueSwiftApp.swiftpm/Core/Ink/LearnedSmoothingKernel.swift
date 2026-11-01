import Foundation

/// Der gelernte Glättungskern: das Stück, das die App aus dem Schreiben lernt.
///
/// Idee: Die App rechnet nach jedem fertigen Strich aus, wie die *schöne* Linie
/// aussieht (Beautifier). Aus vielen solchen Paaren (roh ↔ schön) wird per
/// kleinster Quadrate ein FIR-Kern gelernt, der aus den Rohpunkten möglichst
/// direkt die schöne Linie schätzt. Beim Schreiben wird dieser gelernte Kern
/// live angewendet – die Linie sieht also schon *während* des Schreibens so aus,
/// wie die App den Schreiber inzwischen kennt, statt mit festen Werten.
///
/// Ein Startwert (Gauß-Kern) ist vorhanden; er wird mit wachsender Erfahrung
/// durch die gelernten Gewichte ersetzt. Der Kern bleibt dabei immer auf Summe
/// 1 normiert, damit die Linie nicht wandert.
struct LearnedSmoothingKernel: Equatable {
    /// Anzahl der Abgriffpunkte (ungerade, damit der Kern zentriert ist).
    private(set) var taps: Int
    /// Gewichte, Summe = 1.
    private(set) var weights: [Double]
    /// Wie viele Striche in die Schätzung eingeflossen sind.
    private(set) var observations: Int

    init(taps: Int = 7, weights: [Double]? = nil, observations: Int = 0) {
        let clampedTaps = max(3, taps | 1)
        self.taps = clampedTaps
        let fallback = LearnedSmoothingKernel.gaussianWeights(taps: clampedTaps, sigma: 1.6)
        if let weights, weights.count == clampedTaps {
            self.weights = LearnedSmoothingKernel.normalized(weights)
        } else {
            self.weights = fallback
        }
        self.observations = observations
    }

    static func prior(taps: Int = 7, sigma: Double = 1.6) -> LearnedSmoothingKernel {
        LearnedSmoothingKernel(taps: taps, weights: gaussianWeights(taps: taps, sigma: sigma))
    }

    var half: Int { taps / 2 }

    /// Wie stark die gelernten Gewichte schon zählen (0 … 1).
    var confidence: Double {
        InkMath.clamp(Double(observations) / 16, 0, 1) * 0.65
    }

    var isTrained: Bool { observations > 0 }

    /// Wie der Kern über die Enden der Linie hinweg denkt.
    enum EdgeMode: Equatable {
        /// Randwert fortsetzen. Für die endgültige Linie: sie soll nicht über
        /// die Stelle hinauslaufen, an der der Stift abgehoben hat.
        case clamp
        /// Richtung linear fortführen. Für die Live-Vorschau: existiert dort
        /// noch keine „Zukunft“, wird die aktuelle Richtung verlängert – so
        /// bleibt die Spitze an der Stiftspitze, statt hinterherzuziehen.
        case extrapolate
    }

    /// Wendet den Kern zentriert auf die Punktreihe an.
    func apply(_ points: [Vec2], edge: EdgeMode = .clamp) -> [Vec2] {
        let count = points.count
        guard count > 2 else { return points }

        let first = points[0]
        let second = points[1]
        let last = points[count - 1]
        let beforeLast = points[count - 2]

        var result = points
        for i in 0..<count {
            var x = 0.0
            var y = 0.0
            for k in 0..<taps {
                let index = i + k - half
                if index < 0 {
                    var point = first
                    if edge == .extrapolate {
                        point = first + (first - second) * Double(-index)
                    }
                    x += weights[k] * point.x
                    y += weights[k] * point.y
                    continue
                }
                if index > count - 1 {
                    var point = last
                    if edge == .extrapolate {
                        point = last + (last - beforeLast) * Double(index - (count - 1))
                    }
                    x += weights[k] * point.x
                    y += weights[k] * point.y
                    continue
                }
                x += weights[k] * points[index].x
                y += weights[k] * points[index].y
            }
            result[i] = Vec2(x, y)
        }
        return result
    }

    /// Lernt aus einem Paar (rohe Linie, schöne Linie) dazu.
    ///
    /// Beide Reihen müssen gleich lang sein (die aufrufende Stelle resampelt
    /// entsprechend). Es werden nur Stützstellen gelernt, an denen der Kern
    /// vollständig innerhalb der Linie liegt.
    mutating func learn(raw: [Vec2], target: [Vec2]) {
        let count = min(raw.count, target.count)
        guard count > taps + 2, taps > 2 else { return }

        var rows: [[Double]] = []
        var targets: [Double] = []
        rows.reserveCapacity(2 * (count - taps))

        for i in half..<(count - half) {
            var row = [Double](repeating: 0, count: taps)
            for k in 0..<taps {
                row[k] = raw[i + k - half].x
            }
            rows.append(row)
            targets.append(target[i].x)

            var columnRow = [Double](repeating: 0, count: taps)
            for k in 0..<taps {
                columnRow[k] = raw[i + k - half].y
            }
            rows.append(columnRow)
            targets.append(target[i].y)
        }

        guard rows.count > taps else { return }
        let ridge = 0.002 * Double(rows.count)
        let fit = LinearAlgebra.leastSquares(rows: rows, targets: targets, ridge: ridge)
        guard let solution = fit, solution.count == taps else { return }

        var clamped = solution.map { InkMath.clamp($0, -0.8, 1.6) }
        var total = 0.0
        for value in clamped { total += value }
        guard total > 0.2 else { return }
        for index in 0..<taps {
            clamped[index] /= total
        }

        // Sanft mit dem Vorwissen mischen: neue Striche sollen den Kern
        // verbessern, nicht umwerfen.
        let blend = min(0.55, Double(observations + 1) / 12)
        var blended = [Double](repeating: 0, count: taps)
        for index in 0..<taps {
            blended[index] = (1 - blend) * weights[index] + blend * clamped[index]
        }
        weights = LearnedSmoothingKernel.normalized(blended)
        observations += 1
    }

    /// Setzt den Kern auf den Startwert zurück.
    mutating func reset() {
        weights = LearnedSmoothingKernel.gaussianWeights(taps: taps, sigma: 1.6)
        observations = 0
    }

    static func gaussianWeights(taps: Int, sigma: Double) -> [Double] {
        let half = taps / 2
        var values = [Double](repeating: 0, count: taps)
        for k in 0..<taps {
            let distance = Double(k - half)
            values[k] = exp(-0.5 * pow(distance / max(sigma, 0.35), 2))
        }
        return normalized(values)
    }

    static func normalized(_ values: [Double]) -> [Double] {
        var total = 0.0
        for value in values { total += value }
        guard abs(total) > 1e-12 else { return values }
        return values.map { $0 / total }
    }
}
