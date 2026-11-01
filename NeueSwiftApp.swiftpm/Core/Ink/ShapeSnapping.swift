import Foundation

/// Zieht Linien sanft auf die passende Grundform zu.
///
/// Wenn ein Abschnitt fast gerade ist, ist es *fast immer* besser, ihn ganz
/// gerade zu machen: Genau die letzten Zehntelpunkte Welligkeit sind es, die
/// Handschrift unruhig wirken lassen. Dasselbe gilt für Kreisbögen. Die Stärke
/// des Zugs hängt vom Fehler ab – passt die Form schlecht, wird nur wenig
/// verändert, passt sie gut, wird der Abschnitt wirklich gerade.
enum ShapeSnapping {
    /// Wendet die Formanpassung auf jeden Abschnitt zwischen zwei Ecken an.
    static func applyPerSegment(
        _ points: [Vec2],
        corners: [Bool],
        tolerance: Double
    ) -> [Vec2] {
        guard points.count >= 4 else { return points }
        var result = points
        for range in PolylineGeometry.segments(points.count, corners: corners) {
            guard range.count >= 4 else { continue }
            let slice = Array(points[range])
            let snapped = snap(slice, tolerance: tolerance)
            guard snapped.count == slice.count else { continue }
            for i in 0..<snapped.count {
                result[range.lowerBound + i] = snapped[i]
            }
        }
        return result
    }

    /// Zieht eine Punktreihe auf Gerade oder Kreis zu, wenn sie dazu passt.
    static func snap(_ points: [Vec2], tolerance: Double) -> [Vec2] {
        guard points.count >= 4, tolerance > 0 else { return points }
        let length = PolylineGeometry.totalLength(points)
        guard length > 5 else { return points }

        if let line = PrimitiveFitting.fitLine(points), line.rms < tolerance {
            let weight = InkMath.clamp(1 - line.rms / tolerance, 0, 1) * 0.9
            guard weight > 0.02 else { return points }
            return points.map { point in
                let along = (point - line.point).dot(line.direction)
                let projected = line.point + line.direction * along
                return point + (projected - point) * weight
            }
        }

        let circleTolerance = tolerance * 0.8
        if let circle = PrimitiveFitting.fitCircle(points), circle.fitsArc(circleTolerance) {
            let weight = InkMath.clamp(1 - circle.rms / circleTolerance, 0, 1) * 0.8
            guard weight > 0.02 else { return points }
            return points.map { point in
                let offset = point - circle.center
                let distance = offset.length
                guard distance > 1e-6 else { return point }
                let projected = circle.center + offset * (circle.radius / distance)
                return point + (projected - point) * weight
            }
        }

        return points
    }
}
