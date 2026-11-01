import Foundation

/// Findet echte Ecken in einem Strich.
///
/// Wichtig für die Schrift: Eine „n“-Spitze oder ein „v“-Knick muss scharf
/// bleiben. Wer einfach alles glättet, bekommt weiche, verwaschene Buchstaben.
/// Eine Ecke ist hier ein Punkt, an dem sich die Richtung innerhalb eines
/// kurzen Bogenstücks deutlich dreht – unterdrückt wird alles, was nur ein
/// Zittern ist.
enum CornerDetector {
    /// - Parameters:
    ///   - spacing: Punktabstand der Reihe in Seitenpunkten.
    ///   - angleThreshold: Drehwinkel in Radiant, ab dem ein Knick als Ecke gilt.
    ///   - radius: Bogenlänge vor und hinter dem Punkt, über die gemessen wird.
    static func detect(
        points: [Vec2],
        spacing: Double,
        angleThreshold: Double = 1.02,
        radius: Double = 2.2
    ) -> [Bool] {
        let count = points.count
        var result = [Bool](repeating: false, count: count)
        guard count > 4 else { return result }

        let window = max(1, Int((radius / max(spacing, 0.05)).rounded()))
        guard window * 2 + 1 < count else { return result }

        var strength = [Double](repeating: 0, count: count)
        for i in window..<(count - window) {
            let behind = points[i] - points[i - window]
            let ahead = points[i + window] - points[i]
            guard behind.length > 1e-6, ahead.length > 1e-6 else { continue }
            let cosine = InkMath.clamp(behind.normalized.dot(ahead.normalized), -1, 1)
            strength[i] = acos(cosine)
        }

        // Nur lokale Maxima behalten, damit ein einzelner Knick nicht als
        // mehrere Ecken zählt.
        for i in window..<(count - window) where strength[i] > angleThreshold {
            var isPeak = true
            for j in (i - window)...(i + window) where j != i {
                if strength[j] > strength[i] {
                    isPeak = false
                    break
                }
                if strength[j] == strength[i] && j < i {
                    isPeak = false
                    break
                }
            }
            result[i] = isPeak
        }
        return result
    }

    /// Indizes der Ecken (aufsteigend).
    static func cornerIndices(of flags: [Bool]) -> [Int] {
        var result: [Int] = []
        for (index, flag) in flags.enumerated() where flag {
            result.append(index)
        }
        return result
    }
}
