import Foundation

/// Verbindet Strich-Enden mit benachbarten Strichen.
///
/// Handschrift lebt von Verbindungen: das „a“ endet dort, wo der nächste
/// Buchstabe beginnt. Weil beim schnellen Schreiben der Stift ein paar
/// Zehntelpunkte daneben landet, entstehen kleine Lücken und Versätze. Der
/// Welder zieht das Ende auf den nächsten Punkt des Nachbarstrichs – mit
/// weichem Übergang, damit kein Knick entsteht.
enum JunctionWelder {
    struct WeldResult {
        var points: [InkPoint]
        var weldedStart: Bool
        var weldedEnd: Bool
    }

    /// - Parameters:
    ///   - stroke: der neue Strich (wird nicht verändert, Ergebnis zurückgeben).
    ///   - neighbors: bereits vorhandene Striche (nur aktuelle, nicht die ganze Seite).
    ///   - radius: größter Abstand, der noch als Verbindung gilt.
    static func weld(
        _ stroke: [InkPoint],
        to neighbors: [[InkPoint]],
        radius: Double
    ) -> WeldResult {
        guard stroke.count > 3, !neighbors.isEmpty, radius > 0 else {
            return WeldResult(points: stroke, weldedStart: false, weldedEnd: false)
        }

        var result = stroke
        var weldedStart = false
        var weldedEnd = false

        if let target = closestTarget(to: stroke[0].position, in: neighbors, radius: radius) {
            result = pull(result, toward: target, fromStart: true)
            weldedStart = true
        }
        if let target = closestTarget(
            to: stroke[stroke.count - 1].position, in: neighbors, radius: radius
        ) {
            result = pull(result, toward: target, fromStart: false)
            weldedEnd = true
        }

        return WeldResult(points: result, weldedStart: weldedStart, weldedEnd: weldedEnd)
    }

    /// Nächster Punkt der Nachbarstriche, sofern er nah genug ist.
    static func closestTarget(
        to point: Vec2, in neighbors: [[InkPoint]], radius: Double
    ) -> Vec2? {
        var best: (distance: Double, point: Vec2)?
        for stroke in neighbors {
            let positions = stroke.map { $0.position }
            guard let candidate = PolylineGeometry.closestPointOnPolyline(
                point, points: positions
            ) else { continue }
            guard candidate.distance <= radius else { continue }
            if best == nil || candidate.distance < best!.distance {
                best = (candidate.distance, candidate.point)
            }
        }
        guard let best else { return nil }
        return best.point
    }

    /// Zieht ein Ende auf das Ziel und verteilt den Zug auf die Nachbarpunkte.
    static func pull(_ points: [InkPoint], toward target: Vec2, fromStart: Bool) -> [InkPoint] {
        guard points.count > 2 else { return points }
        let weights: [Double] = [1, 0.55, 0.26, 0.1]
        var result = points
        for (offset, weight) in weights.enumerated() {
            let index = fromStart ? offset : result.count - 1 - offset
            guard index >= 0, index < result.count else { continue }
            let current = result[index].position
            result[index].position = current + (target - current) * weight
        }
        return result
    }
}
